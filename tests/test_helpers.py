import sys
import tempfile
import unittest
from pathlib import Path

import _paths  # noqa: F401

sys.path.insert(0, str(_paths.ROOT / "scripts"))

from apply_reply import apply_reply, check_path  # noqa: E402
from bundle import build_bundle, referenced_files  # noqa: E402


class CheckPathTests(unittest.TestCase):
    def test_allowed_locations(self):
        for rel in ("app/lib/main.dart", "app/test/a_test.dart", "firmware/lib/phase_detector/x.cpp",
                    "PROGRESS.md", "docs/LAUNCH_DAY.md"):
            with self.subTest(rel):
                self.assertIsNone(check_path(rel))

    def test_protected_and_unsafe_locations_are_refused(self):
        for rel in ("protocol/vectors.json", "tools/vector_packet.py", "sim/simulate.py",
                    "tests/test_packet.py", "tasks/01_create_app.md", "scripts/check.py",
                    "AGENTS.md", "README.md", "requirements.txt",
                    "firmware/lib/vector_packet/vector_packet.cpp",
                    "firmware/test/test_packet/test_main.cpp",
                    "../outside.txt", "app/../tools/x.py", "/etc/passwd", "C:/x.txt",
                    "app\\lib\\x.dart", "", "app//x.dart", "app/./x.dart"):
            with self.subTest(rel):
                self.assertIsNotNone(check_path(rel))


class ApplyReplyTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "app" / "lib").mkdir(parents=True)
        (self.root / "protocol").mkdir()
        (self.root / "protocol" / "vectors.json").write_text("original")

    def tearDown(self):
        self._tmp.cleanup()

    def test_creates_files_and_parent_folders(self):
        reply = ("Here you go.\n\nFILE: app/lib/protocol/crc16.dart\n```dart\nint crc() => 1;\n```\n"
                 "\nThat's it.")
        written, refused, _ = apply_reply(reply, self.root)
        self.assertEqual(written, [("app/lib/protocol/crc16.dart", "created")])
        self.assertEqual(refused, [])
        self.assertEqual((self.root / "app/lib/protocol/crc16.dart").read_text(), "int crc() => 1;\n")

    def test_replaces_and_backs_up_existing_files(self):
        (self.root / "app/lib/main.dart").write_text("old")
        written, _, _ = apply_reply("FILE: app/lib/main.dart\n```dart\nnew\n```", self.root)
        self.assertEqual(written, [("app/lib/main.dart", "replaced")])
        self.assertEqual((self.root / "app/lib/main.dart").read_text(), "new\n")
        backups = list((self.root / ".backups").rglob("main.dart"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "old")

    def test_protected_files_are_refused_and_left_alone(self):
        reply = ("FILE: protocol/vectors.json\n```json\n{}\n```\n\n"
                 "FILE: app/lib/ok.dart\n```dart\nok\n```")
        written, refused, _ = apply_reply(reply, self.root)
        self.assertEqual([w[0] for w in written], ["app/lib/ok.dart"])
        self.assertEqual([r[0] for r in refused], ["protocol/vectors.json"])
        self.assertEqual((self.root / "protocol/vectors.json").read_text(), "original")

    def test_path_escape_attempt_writes_nothing(self):
        written, refused, _ = apply_reply("FILE: app/../../evil.txt\n```\nx\n```", self.root)
        self.assertEqual(written, [])
        self.assertEqual(len(refused), 1)
        self.assertFalse((self.root.parent / "evil.txt").exists())

    def test_handles_longer_fences_backticked_paths_and_windows_line_endings(self):
        md = "# Title\n\n```bash\nls\n```"
        reply = f"FILE: `docs/BUILD.md`\n````markdown\n{md}\n````\n".replace("\n", "\r\n")
        written, refused, _ = apply_reply(reply, self.root)
        self.assertEqual(refused, [])
        self.assertEqual(written, [("docs/BUILD.md", "created")])
        self.assertEqual((self.root / "docs/BUILD.md").read_text(), md + "\n")

    def test_dry_run_changes_nothing(self):
        written, _, _ = apply_reply("FILE: app/lib/new.dart\n```dart\nx\n```", self.root, dry_run=True)
        self.assertEqual(written, [("app/lib/new.dart", "created")])
        self.assertFalse((self.root / "app/lib/new.dart").exists())

    def test_commands_are_reported_not_run(self):
        reply = "FILE: app/lib/a.dart\n```dart\na\n```\n\nCOMMANDS:\n```\nflutter pub add web_socket_channel\n```"
        _, _, commands = apply_reply(reply, self.root)
        self.assertEqual(commands, "flutter pub add web_socket_channel")

    def test_duplicate_file_blocks_use_the_first(self):
        reply = "FILE: app/lib/a.dart\n```\nfirst\n```\nFILE: app/lib/a.dart\n```\nsecond\n```"
        written, refused, _ = apply_reply(reply, self.root)
        self.assertEqual(len(written), 1)
        self.assertEqual(len(refused), 1)
        self.assertEqual((self.root / "app/lib/a.dart").read_text(), "first\n")

    def test_reply_without_files_finds_nothing(self):
        self.assertEqual(apply_reply("Sure! I will do that.", self.root), ([], [], ""))


class BundleTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        for d in ("tasks", "protocol", "tools", "app/lib", "app/test"):
            (self.root / d).mkdir(parents=True)
        (self.root / "AGENTS.md").write_text("RULES-TEXT")
        (self.root / "PROGRESS.md").write_text("PROGRESS-TEXT")
        (self.root / "tools/ref.py").write_text("REFERENCE-CODE")
        (self.root / "protocol/data.json").write_text("\n".join(f"line{i}" for i in range(100)))
        (self.root / "tasks/02_demo.md").write_text(
            "# Task 02\nRead `AGENTS.md`, `tools/ref.py`, `protocol/data.json` and `nope/missing.py`.\n")
        (self.root / "app/lib/main.dart").write_text("MAIN-DART-CODE")

    def tearDown(self):
        self._tmp.cleanup()

    def test_contains_everything_needed(self):
        text = build_bundle(2, self.root)
        for needle in ("# Task 02", "RULES-TEXT", "PROGRESS-TEXT", "REFERENCE-CODE",
                       "MAIN-DART-CODE", "FILE: app/lib/protocol/example.dart", "COMMANDS:"):
            with self.subTest(needle):
                self.assertIn(needle, text)

    def test_data_files_are_shortened(self):
        text = build_bundle(2, self.root)
        self.assertIn("line24", text)
        self.assertNotIn("line30", text)
        self.assertIn("the real file has 100 lines", text)

    def test_only_existing_files_are_referenced(self):
        refs = referenced_files((self.root / "tasks/02_demo.md").read_text(), self.root)
        self.assertEqual(refs, ["AGENTS.md", "tools/ref.py", "protocol/data.json"])

    def test_size_limit_drops_optional_files_but_keeps_the_task(self):
        (self.root / "app/lib/big.dart").write_text("X" * 5000)
        text = build_bundle(2, self.root, max_chars=3500)
        self.assertIn("# Task 02", text)
        self.assertIn("RULES-TEXT", text)
        self.assertIn("NOT INCLUDED", text)
        self.assertNotIn("X" * 5000, text)

    def test_includes_latest_check_result(self):
        (self.root / "last_check.txt").write_text("[FAIL] something broke")
        self.assertIn("[FAIL] something broke", build_bundle(2, self.root))

    def test_bundle_forbids_tool_calls_and_includes_my_setup(self):
        (self.root / "MY_SETUP.md").write_text("FEDORA-SETUP-TEXT")
        text = build_bundle(2, self.root)
        self.assertIn("You have NO tools here", text)
        self.assertIn("FEDORA-SETUP-TEXT", text)

    def test_bundle_ends_with_the_closing_instruction(self):
        text = build_bundle(2, self.root, max_chars=500)
        self.assertTrue(text.rstrip().endswith("are written out above."))

    def test_missing_task_number_exits(self):
        with self.assertRaises(SystemExit):
            build_bundle(9, self.root)


if __name__ == "__main__":
    unittest.main()

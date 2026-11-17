"""Save the files from a chat reply into the project, safely.

For use with a chat window (like Open WebUI) that cannot edit files itself.

    python scripts/apply_reply.py reply.txt        # reply saved to a file
    python scripts/apply_reply.py                  # paste the reply, then press Ctrl+D
    python scripts/apply_reply.py reply.txt --dry-run   # show what WOULD happen

The reply must give each file like this (the bundle tells the model to):

    FILE: app/lib/protocol/crc16.dart
    ```dart
    ...the COMPLETE file...
    ```

Safety rules (checked here, not left to the model):
  * only app/, firmware/ and a few named docs can be written;
  * the contract folders (protocol/, tools/, sim/, tests/, tasks/, scripts/) and the
    packet library in firmware/ are refused;
  * nothing outside the project, no '..', no absolute paths;
  * any file that already exists is copied to .backups/<time>/ before being replaced;
  * commands the model suggests are shown to you, never run.
"""
from __future__ import annotations

import datetime
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ALLOWED_PREFIXES = ("app/", "firmware/")
ALLOWED_FILES = {
    "PROGRESS.md",
    "docs/HARDWARE_DECISIONS.md",
    "docs/LAUNCH_DAY.md",
    "docs/BUILD.md",
}
# Inside an allowed prefix, these are still the contract and cannot be written.
PROTECTED_PREFIXES = (
    "firmware/lib/vector_packet/",
    "firmware/test/test_packet/",
)

_FILE_BLOCK = re.compile(
    r"^[ \t]*FILE:[ \t]*(?P<path>[^\n]+?)[ \t]*\n"
    r"(?P<fence>`{3,})[^\n]*\n"
    r"(?P<body>.*?)\n"
    r"(?P=fence)[ \t]*$",
    re.MULTILINE | re.DOTALL,
)
_COMMANDS_BLOCK = re.compile(
    r"^[ \t]*COMMANDS:[ \t]*\n(?P<fence>`{3,})[^\n]*\n(?P<body>.*?)\n(?P=fence)[ \t]*$",
    re.MULTILINE | re.DOTALL,
)


def clean_path(raw: str) -> str:
    return raw.strip().strip("`").strip().strip("'\"").strip()


def check_path(rel: str, root: Path = ROOT) -> str | None:
    """Return None if the path may be written, else a plain-language reason."""
    if not rel:
        return "empty path"
    if "\\" in rel:
        return "backslashes are not allowed; use forward slashes"
    if rel.startswith("/") or re.match(r"^[A-Za-z]:", rel):
        return "absolute paths are not allowed"
    parts = rel.split("/")
    if any(p in ("", ".", "..") for p in parts):
        return "'..' and empty parts are not allowed"
    if rel.startswith(PROTECTED_PREFIXES):
        return "this file is part of the contract and is protected"
    if not (rel in ALLOWED_FILES or rel.startswith(ALLOWED_PREFIXES)):
        return "this location is protected (only app/, firmware/ and a few docs can be written)"
    target = (root / rel).resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError:
        return "the path leaves the project folder"
    return None


def apply_reply(text: str, root: Path = ROOT, dry_run: bool = False):
    """Return (written, refused, commands). `written` and `refused` are lists of
    (path, note) pairs; `commands` is the text of a COMMANDS block or ''."""
    text = text.replace("\r\n", "\n")
    written: list[tuple[str, str]] = []
    refused: list[tuple[str, str]] = []
    seen: set[str] = set()
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    for m in _FILE_BLOCK.finditer(text):
        rel = clean_path(m.group("path"))
        body = m.group("body") + "\n"
        reason = check_path(rel, root)
        if reason:
            refused.append((rel, reason))
            continue
        if rel in seen:
            refused.append((rel, "listed twice in the reply; the first copy was used"))
            continue
        seen.add(rel)
        target = root / rel
        note = "replaced" if target.exists() else "created"
        if not dry_run:
            if target.exists():
                backup = root / ".backups" / stamp / rel
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, backup)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(body, encoding="utf-8")
        written.append((rel, note))

    cm = _COMMANDS_BLOCK.search(text)
    return written, refused, (cm.group("body").strip() if cm else "")


def main(argv: list[str]) -> int:
    dry_run = "--dry-run" in argv
    args = [a for a in argv if not a.startswith("--")]
    if args:
        text = Path(args[0]).read_text(encoding="utf-8", errors="replace")
    else:
        print("Paste the model's reply here, then press Ctrl+D on an empty line:")
        text = sys.stdin.read()

    written, refused, commands = apply_reply(text, ROOT, dry_run=dry_run)

    if not written and not refused:
        print("\nNo files found in that reply.")
        print("Each file must start with a line like  FILE: app/lib/main.dart  followed by a code block.")
        print("Ask the model: 'Resend, giving each complete file as FILE: path then a code block.'")
        return 1

    verb = "Would write" if dry_run else "Wrote"
    if written:
        print(f"\n{verb} {len(written)} file(s):")
        for rel, note in written:
            print(f"  {note:9} {rel}")
        if not dry_run and any(n == "replaced" for _, n in written):
            print("  (replaced files were backed up in .backups/)")
    if refused:
        print(f"\nREFUSED {len(refused)} file(s):")
        for rel, reason in refused:
            print(f"  {rel}\n      {reason}")
        print("\nIf the model needs to change a protected file, do NOT allow it.")
        print("Paste the refusal to Claude instead.")
    if commands:
        print("\nThe model suggests running these commands. Read them first; nothing was run:")
        for line in commands.splitlines():
            print(f"  {line}")
    print("\nNext: python scripts/check.py")
    return 1 if refused else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

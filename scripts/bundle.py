"""Make one file that holds everything a chat window needs for a task.

    python scripts/bundle.py 5            # writes bundles/task_05.md

Attach (or paste) that one file into Open WebUI, then send:
    "Do the task in this bundle."

It contains: the rules, the progress notes, the task, the project files the task points at,
the current app code, the latest check result, and the exact format the reply must use
(so python scripts/apply_reply.py can save it).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_TOTAL_CHARS = 60_000      # about 15,000 tokens; keeps small models focused
DATA_SUFFIXES = {".json", ".hex", ".csv", ".h"}
DATA_HEAD_LINES = 25
SKIP_DIRS = {".dart_tool", "build", ".git", ".idea", "node_modules", ".pio", "__pycache__", ".backups"}

PREFACE = """\
# Vector: one task, as a chat

You are the coding assistant for Vector, a rocket-tracking app. You are in a chat window.
You CANNOT run commands, edit files or see the screen. The person will save your files and run the checks.

So, in this chat:
- You have NO tools here. Never call a tool or function (not ask_user, not get_current_timestamp, not anything else).
  If you truly need an answer from the person, write the question as ordinary text and stop.
- Do ONLY the task below. Follow the rules in AGENTS.md (ignore its parts about running commands yourself).
- Give every file you create or change as a COMPLETE file, never a fragment, never "rest unchanged".
- Use exactly this format for each file, so a script can save it:

FILE: app/lib/protocol/example.dart
```dart
// the complete contents of the file
```

- Only write files under app/ or firmware/ (and PROGRESS.md). Never write files in protocol/, tools/, sim/, tests/.
- After the files, list any commands the person must run, in one block starting with the line COMMANDS:

COMMANDS:
```
flutter pub add some_package
```

- Finish with at most 5 plain lines telling the person what you did and how to see it work.
- If something is unclear or the task needs a protected change, stop and ask one short question instead of guessing.
"""


CLOSING = """\
## NOW DO THIS
Write your reply now, as plain text, in this order:
1. Every file the task needs, each as `FILE: path` then a code block with the COMPLETE file.
2. One `COMMANDS:` block with the commands the person must run.
3. At most 5 plain lines of explanation.
Do not call any tool, do not make a to-do list, and do not say the task is done until the FILES and COMMANDS are written out above.
"""


def find_task(n: int, root: Path = ROOT) -> Path:
    matches = sorted((root / "tasks").glob(f"{n:02d}_*.md"))
    if not matches:
        raise SystemExit(f"No task file for number {n} in tasks/.")
    return matches[0]


def _fence(path: str, text: str) -> str:
    lang = Path(path).suffix.lstrip(".") or ""
    fence = "````" if "```" in text else "```"
    return f"### {path}\n{fence}{lang}\n{text.rstrip()}\n{fence}\n"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def referenced_files(task_text: str, root: Path = ROOT) -> list[str]:
    """Backticked paths in the task that exist in the project (skips the app and firmware
    folders themselves, which are handled separately)."""
    found: list[str] = []
    for token in re.findall(r"`([^`\n]+)`", task_text):
        token = token.strip().lstrip("./")
        p = root / token
        if token and p.is_file() and token not in found:
            found.append(token)
    return found


def _code_files(root: Path, task_number: int) -> list[Path]:
    areas = [root / "app" / "lib", root / "app" / "test"]
    singles = [root / "app" / "pubspec.yaml"]
    if task_number >= 10:
        areas += [root / "firmware" / "lib", root / "firmware" / "test"]
        singles += [root / "firmware" / "platformio.ini"]
    files = [p for p in singles if p.is_file()]
    for area in areas:
        if area.is_dir():
            files += [p for p in area.rglob("*") if p.is_file()
                      and not (set(p.relative_to(root).parts) & SKIP_DIRS)
                      and p.suffix in {".dart", ".cpp", ".h", ".ini", ".yaml"}]
    # Newest first, so recent work is kept if the size limit forces a cut.
    return sorted(files, key=lambda p: p.stat().st_mtime, reverse=True)


def build_bundle(n: int, root: Path = ROOT, max_chars: int = MAX_TOTAL_CHARS) -> str:
    task_path = find_task(n, root)
    task_text = _read(task_path)
    parts: list[str] = [PREFACE]
    used = len(PREFACE)
    omitted: list[str] = []

    def add(title: str, body: str, essential: bool = False) -> None:
        nonlocal used
        if not essential and used + len(body) > max_chars:
            omitted.append(title)
            return
        parts.append(body)
        used += len(body)

    task_rel = task_path.relative_to(root).as_posix()
    add(task_rel, "## THE TASK\n" + _fence(task_rel, task_text), essential=True)
    if (root / "MY_SETUP.md").is_file():
        add("MY_SETUP.md", "## ABOUT THE PERSON'S COMPUTER (MY_SETUP.md)\n"
            + _fence("MY_SETUP.md", _read(root / "MY_SETUP.md")), essential=True)
    for name in ("AGENTS.md", "PROGRESS.md"):
        if (root / name).is_file():
            label = "THE RULES (AGENTS.md)" if name == "AGENTS.md" else "PROGRESS SO FAR (PROGRESS.md)"
            add(name, "## " + label + "\n" + _fence(name, _read(root / name)), essential=True)

    ref_blocks: list[str] = []
    for rel in referenced_files(task_text, root):
        if rel in ("AGENTS.md", "PROGRESS.md") or rel.startswith(("app/", "tasks/")):
            continue
        p = root / rel
        text = _read(p)
        if rel.startswith("protocol/") and p.suffix in DATA_SUFFIXES:
            lines = text.splitlines()
            if len(lines) > DATA_HEAD_LINES:
                text = "\n".join(lines[:DATA_HEAD_LINES]) + \
                    f"\n... (shortened here; the real file has {len(lines)} lines)"
        ref_blocks.append((rel, _fence(rel, text)))
    if ref_blocks:
        parts.append("## FILES THE TASK POINTS AT (read only)\n")
        for rel, block in ref_blocks:
            add(rel, block)

    check = root / "last_check.txt"
    if check.is_file():
        add("last_check.txt", "## LATEST CHECK RESULT\n" + _fence("last_check.txt", _read(check)))

    code = _code_files(root, n)
    if code:
        parts.append("## CURRENT PROJECT CODE (the files that already exist)\n")
        for p in code:
            rel = p.relative_to(root).as_posix()
            add(rel, _fence(rel, _read(p)))
    else:
        parts.append("## CURRENT PROJECT CODE\n(none yet)\n")

    if omitted:
        parts.append("## NOT INCLUDED (too long for one bundle)\n"
                     + "\n".join(f"- {o}" for o in omitted)
                     + "\nIf you need one of these, ask the person to paste it.\n")
    parts.append(CLOSING)
    return "\n".join(parts)


def main(argv: list[str]) -> int:
    if len(argv) != 1 or not argv[0].isdigit():
        print("Usage: python scripts/bundle.py <task number>     for example: python scripts/bundle.py 5")
        return 2
    n = int(argv[0])
    text = build_bundle(n)
    out_dir = ROOT / "bundles"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / f"task_{n:02d}.md"
    out.write_text(text, encoding="utf-8")
    approx_tokens = len(text) // 4
    print(f"Wrote {out.relative_to(ROOT)}  ({len(text):,} characters, about {approx_tokens:,} tokens)")
    if "## NOT INCLUDED" in text:
        print("Note: some files were left out to keep it short (listed at the end of the bundle).")
    print("\nNext: attach that file in Open WebUI (or paste its text) and send:")
    print("  Do the task in this bundle.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

"""One command that checks everything that can be checked.

    python scripts/check.py

It prints PASS / FAIL / SKIP for each part in plain language and saves the
details to last_check.txt. If anything says FAIL, paste last_check.txt to
Claude Code.
"""
from __future__ import annotations

import datetime
import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TAIL_LINES = 60


def run(cmd: list[str], cwd: Path, timeout: int = 900) -> tuple[bool, str]:
    try:
        proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return False, f"Timed out after {timeout} seconds: {' '.join(cmd)}"
    except OSError as exc:
        return False, f"Could not run {' '.join(cmd)}: {exc}"
    out = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode == 0, out


def tail(text: str, n: int = TAIL_LINES) -> str:
    lines = text.strip().splitlines()
    return "\n".join(lines[-n:])


def check_python() -> tuple[str, str, str]:
    name = "Protocol, simulator and test data (Python)"
    if importlib.util.find_spec("websockets") is None:
        return ("FAIL", name, "The 'websockets' library is not installed.\n"
                              "Fix: run   pip install -r requirements.txt")
    ok, out = run([sys.executable, "-I", "-m", "unittest", "discover", "-s", "tests"], ROOT)
    summary = [ln for ln in out.splitlines() if ln.startswith(("Ran ", "OK", "FAILED"))]
    return ("PASS" if ok else "FAIL", name, tail(out) if not ok else " ".join(summary))


def check_app() -> list[tuple[str, str, str]]:
    app = ROOT / "app"
    name = "App"
    if not (app / "pubspec.yaml").exists():
        return [("SKIP", name, "The app has not been created yet (task 01).")]
    flutter = shutil.which("flutter")
    if not flutter:
        return [("SKIP", name, "Flutter is not installed or not on PATH (see docs/SETUP.md).")]
    results = []
    ok, out = run([flutter, "analyze"], app)
    results.append(("PASS" if ok else "FAIL", "App: flutter analyze (finds mistakes in the code)",
                    "" if ok else tail(out)))
    ok, out = run([flutter, "test"], app)
    passed = [ln for ln in out.splitlines() if "All tests passed" in ln]
    results.append(("PASS" if ok else "FAIL", "App: flutter test (runs the app's tests)",
                    passed[-1].strip() if ok and passed else tail(out)))
    return results


def check_firmware() -> tuple[str, str, str]:
    name = "Firmware tests (C++: packet library and phase detector)"
    fw = ROOT / "firmware"
    if not (fw / "platformio.ini").exists():
        return ("SKIP", name, "Not created yet (task 10).")
    pio = shutil.which("pio") or shutil.which("platformio")
    if not pio:
        return ("SKIP", name, "PlatformIO is not installed (see docs/SETUP.md).")
    ok, out = run([pio, "test", "-e", "native"], fw)
    return ("PASS" if ok else "FAIL", name, "" if ok else tail(out))


def main() -> int:
    results: list[tuple[str, str, str]] = [check_python(), *check_app(), check_firmware()]
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = [f"Vector check, {stamp}", ""]
    for status, name, detail in results:
        lines.append(f"[{status}] {name}")
        if detail and status != "PASS":
            lines.extend("      " + ln for ln in detail.splitlines())
        elif detail and status == "PASS":
            lines.append("      " + detail)
    fails = [r for r in results if r[0] == "FAIL"]
    lines.append("")
    if fails:
        lines.append(f"RESULT: {len(fails)} thing(s) need fixing. Paste this whole file to Claude Code.")
    else:
        lines.append("RESULT: everything that can be checked right now passes.")
    report = "\n".join(lines) + "\n"
    (ROOT / "last_check.txt").write_text(report)
    print(report)
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())

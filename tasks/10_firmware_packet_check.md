# Task 10: Firmware packet library check

## Goal
Confirm the C++ packet library passes its tests in the real build tool (PlatformIO), on the person's computer.

## Background
The library in `firmware/lib/vector_packet/` is already written. It was tested with a stand-in test runner, not
PlatformIO's own, so this task proves it under the real one.

## Read first
`AGENTS.md`, `firmware/platformio.ini`, `firmware/test/test_packet/test_main.cpp`.

## Do
1. Make sure PlatformIO is installed (`docs/SETUP.md`, step 5). Then run `cd firmware && pio test -e native`.
2. If it fails because of the build setup (an include path, a missing header, the test framework), you may fix
   files inside `firmware/` (but never `protocol/`). If a test fails because the **numbers disagree** with
   `protocol/vectors.h`, stop: tell the person to ask Claude.
3. Run `python scripts/check.py`. The firmware line must say PASS.

## Done when
`pio test -e native` reports 7 tests passed, and `python scripts/check.py` shows PASS for the firmware.

## Then
Tick task 10.

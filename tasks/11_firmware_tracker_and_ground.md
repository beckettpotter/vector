# Task 11: Firmware: tracker and ground node

## Goal
The code that runs on the rocket tracker and the ground node. **This is the safety-critical part of the
project. Part B must not be written without a club member who reviews the code.**

## Read first
`AGENTS.md` (safety rules), `protocol/PROTOCOL.md`, `firmware/lib/vector_packet/vector_packet.h`.

## Part A: pure logic (do this now)
1. `firmware/lib/phase_detector/phase_detector.h` and `.cpp`: no hardware, no Arduino. Input: barometric altitude
   above the pad in cm, vertical speed in cm/s, time in ms. Output: the phase (pad, boost, coast, apogee, descent,
   landed). Rules to implement, with the thresholds as named constants at the top of the file so the club can tune them:
   - pad to boost: vertical speed above 10 m/s and altitude above 10 m;
   - boost to coast: when upward speed stops increasing for 0.3 s (burnout);
   - coast to apogee: vertical speed at or below 0;
   - apogee to descent: 2 s after apogee;
   - descent to landed: altitude within 5 m of the pad and vertical speed within 1 m/s for 5 s in a row;
   - phases never go backward.
2. Native tests in `firmware/test/test_phase/` that drive the detector with a made-up flight (build the series in
   the test: a rising speed, a coast, a fall at 6.5 m/s) and check the phase sequence and the times of each change.
   Also test noise: small jitter on the pad must not cause a launch.
3. Run `pio test -e native` and `python scripts/check.py`.

## Part B: boards (STOP; needs the club)
Do not start this part. Create `docs/HARDWARE_DECISIONS.md` that lists these questions and leaves answers blank:
which LoRa board for the tracker and for the ground node; which GPS module and barometer; the radio frequency
band and spreading settings; transmit power; who is the reviewer. Tell the person to take it to the club and then
to Claude. Never invent radio settings, pin numbers or battery code.

## Done when
Part A tests pass, `docs/HARDWARE_DECISIONS.md` exists, and `PROGRESS.md` says "Part B: waiting for club review".

## Then
Tick task 11 only for Part A and say so in `PROGRESS.md`.

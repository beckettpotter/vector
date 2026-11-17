# Progress

The coding assistant updates this file after every task. Newest note last.

## Tasks

- [x] 01 Create the app and make it run
- [x] 02 Decode packets in the app
- [x] 03 Flight statistics
- [x] 04 Connect to the simulator
- [x] 05 Live instrument panel (HUD)
- [x] 06 Track plot (map tiles later)
- [x] 07 Flight recording and history
- [x] 08 Recovery view
- [x] 09 Export and replay
- [ ] 10 Firmware: packet library check
- [x] 11 Firmware: phase detector now; boards need a club review (Part A only)
- [ ] 12 Polish and the launch-day checklist

## Notes

- Kit created. Python tests, the simulator, the test data and the C++ packet library are already done and passing.
- 2026-11-17: Devstral could not build the app (it never wrote files). The build moved to Claude Code. Read HANDOFF.md first.
- 2026-11-17 (Claude Code): kit moved into the git repo. Task 01 done: dark Vector screen, built and run on Linux in the cloud session (Flutter 3.50.0, which uses `package:material_ui`).
- Task 02 done: Dart decoder; tests loop over all 20 vectors (8 valid, 7 invalid, 3 ground valid, 2 ground invalid) plus the CRC check.
- Task 03 done: sample flight gives apogee 948.5 m, time to apogee 13.0 s, max speed 143.4 m/s, descent 6.4 m/s, flight time 161.0 s, landing distance 619.7 m, 178 packets.
- Task 04 done: WebSocket link with 1/2/5 s reconnect, link monitor (lost, stale 5 s, lost 30 s, new-session rules) with fake-clock tests, and a Connect box. Simulator and Ground node quick-pick buttons included.
- Task 05 done: HUD with STALE/LOST banner, 'last known' greying, feet switch. Verified in the Linux app against the simulator (cloud session, virtual screen): 178 frames, 0 lost, max 948.5 m, all six phases, STALE then LOST after the stream ends.
- Task 06 done: offline track plot (pad, 3D-fix path, dashed GPS gap, phase-coloured dot, rings, north arrow, last-known label) and HUD/Track tabs. Rings are drawn as short segments because big stroked circles rendered as grey boxes with software OpenGL. Map tiles: waiting for a decision on tile source and terms (question for Beckett).
- Task 07 done: automatic recording to plain .hex + .json files, History list and detail (stats, altitude and speed plots, rename, delete with confirmation). Recording starts at the first non-pad packet and keeps up to 30 pad packets from before it (so an idle tracker on the pad is not saved). Files live in Documents/Vector/flights (falls back to ~/.local/share/club.vector.vector/Vector/flights). Verified in the Linux app: simulated flight saved with apogee 948.5 m and all stats matching.
- Task 08 done: Recovery tab with distance, bearing (degrees + 16-point letters), north-up arrow, copyable coordinates, fix age, typed viewer position pre-filled with the pad, and a ROCKET STILL FLYING label. Verified in the Linux app: 620 m, 76 deg ENE after the simulated landing. Device GPS and compass: waiting for a decision (platform permissions).
- Task 09 done: CSV export (byte-identical to sample_flight.csv, also checked on a file exported from the running app), KML export (track, pad, landing), and replay of saved flights at 1x/5x/10x with play/pause and a scrub slider, through the same link monitor (replays are not recorded again). Exports go to Vector/exports/; phones and Mac open the share sheet, Linux shows the saved path (share_plus cannot share files on Linux). Test-only dev package: xml (to check the KML parses).
- Task 10 NOT done: this cloud session cannot reach the PlatformIO registry, so `pio test -e native` must be run on Beckett's computer (see the commands in HANDOFF/README). Nothing in firmware/ changed for it.
- Task 11 Part A done: `firmware/lib/phase_detector/` with 6 native tests in `firmware/test/test_phase/` (made-up flight with sequence and change times, pad jitter, low-altitude speed spike, noisy flight, never backwards, 5 s landing streak). They pass with a local stand-in for Unity; they still need a real `pio test -e native` run. Part B: waiting for club review (`docs/HARDWARE_DECISIONS.md`).

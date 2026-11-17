# Progress

The coding assistant updates this file after every task. Newest note last.

## Tasks

- [x] 01 Create the app and make it run
- [x] 02 Decode packets in the app
- [x] 03 Flight statistics
- [ ] 04 Connect to the simulator
- [ ] 05 Live instrument panel (HUD)
- [ ] 06 Track plot (map tiles later)
- [ ] 07 Flight recording and history
- [ ] 08 Recovery view
- [ ] 09 Export and replay
- [ ] 10 Firmware: packet library check
- [ ] 11 Firmware: phase detector now; boards need a club review
- [ ] 12 Polish and the launch-day checklist

## Notes

- Kit created. Python tests, the simulator, the test data and the C++ packet library are already done and passing.
- 2026-11-17: Devstral could not build the app (it never wrote files). The build moved to Claude Code. Read HANDOFF.md first.
- 2026-11-17 (Claude Code): kit moved into the git repo. Task 01 done: dark Vector screen, built and run on Linux in the cloud session (Flutter 3.50.0, which uses `package:material_ui`).
- Task 02 done: Dart decoder; tests loop over all 20 vectors (8 valid, 7 invalid, 3 ground valid, 2 ground invalid) plus the CRC check.
- Task 03 done: sample flight gives apogee 948.5 m, time to apogee 13.0 s, max speed 143.4 m/s, descent 6.4 m/s, flight time 161.0 s, landing distance 619.7 m, 178 packets.

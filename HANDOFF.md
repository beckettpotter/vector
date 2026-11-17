# Vector: handoff to Claude Code

Written 2026-11-17 from a Claude.ai chat that began 2026-11-16. Read this file first, then `AGENTS.md`,
then `PROGRESS.md`. Everything described here is in this folder unless a section says otherwise.

**The state in one paragraph.** Vector (a rocket-tracking app for a rocketry club, formerly named StarTrack) has a
finished, tested *contract layer*: a written packet protocol, a Python reference implementation, a flight
simulator, generated test data, and a C++ packet library. The *app itself does not exist yet*: `app/` has not been
created, and no Dart or Flutter code has been written or run anywhere. The user tried to have a local model
(Devstral Small 2 via Open WebUI) build the app and it failed, so the user has moved the build to Claude Code.
Your job is to build the Flutter app (tasks 01 to 09 and 12 in `tasks/`) on the user's own machine, where Flutter
can actually run, using the protocol and test data as the objective check.

---

## 1. The user and how to work with them

- Name on the Claude account: Beckett. A member of a rocketry club; flies L1 rockets now, wants to reach IREC scale.
- **Does not write code.** They run commands you give them, report what happens, and look at the screen.
  Therefore: explain in plain words (at most 5 lines), give exact commands one per line with what a good result looks
  like, never ask them to hand-edit code, and do not make them choose between technical options. Pick the simplest
  sensible default and tell them in one line what you chose.
- Machine: **Fedora Linux desktop, no GPU (integrated graphics), 64 GB RAM.** Run the app with `flutter run -d linux`.
  Use `python` (they installed `python-unversioned-command`, per the instructions given), Python 3.10 or newer.
- Local AI they already run: Ollama with Devstral Small 2 (a tuned copy named `devstral-vector` was created from
  `docs/Modelfile`), a Qwen model (size and variant never confirmed), and Open WebUI. CPU-only generation is slow
  (a 24B model on CPU is roughly a few tokens a second), so local models are not a good fit for the main build.
  They now have a Claude Pro subscription and plan to use Claude Code for the build.
- Progress through the setup steps I gave them: they reported being "on step 5" (steps 1 to 4: unzip kit, Python
  check, `ollama create devstral-vector`, install Flutter on Fedora). **Verify rather than assume**: run
  `python scripts/check.py` and `flutter doctor`. I never saw their output.
- Tone: friendly, direct, honest about what is untested. They want it to work, and they were told repeatedly which
  parts are unverified.

## 2. Objective

Build **Vector**: "ForeFlight plus FlightAware for rockets", a cross-platform app (macOS, Windows, Linux, iPhone,
iPad, Android) that gives a rocketry club a live HUD, tracker, recovery help and flight records, with **minimal
hardware and no middlemen** (no cloud, no cell service, no accounts).

- MVP target: **L1 rockets** (H and I motors), apogee up to about 5,000 ft AGL, line-of-sight range of at least 3 km,
  one telemetry packet per second.
- Later: L2/L3, then IREC scale (10,000 and 30,000 ft apogee targets). The versioned packet format is how it grows.
- Schedule: the user wanted MVP rollout "within a month" of 2026-11-16. The brief's plan targets **Monday 2026-12-14**
  with a real flight test around 2026-12-12, assuming parts are ordered the week of 2026-11-16. Thanksgiving week
  (Nov 23 to 29) will be slow. The flight test date depends on when the club next launches. This was never confirmed.
- The user's description of the build method: "vibecoded".

## 3. The brief (source of requirements)

A shareable doc, "Vector: Project Brief", exists at https://claude.ai/artifact/VBaUwsetep8BqhFZzvQWiN (a Claude Docs
artifact; the user can open and edit it). Sections: vision, who it's for and design principles, MVP scope,
system architecture (drawing), reference hardware, app features, tech stack and vibecoding plan, data format
and protocol, roadmap (drawing), four-week plan (drawing), risks/safety/open questions, success criteria.
The user renamed StarTrack to Vector in it themselves; I fixed the one drawing label that still said StarTrack.

**The brief and the kit differ in these places. The kit is newer and wins; offer to update the brief:**

| Brief says | Kit does | Why |
| --- | --- | --- |
| Storage in local SQLite | Flights saved as plain files (`.hex` + `.json`) | Simpler, matches "open file" principle, no desktop database setup |
| Offline map tiles pre-loaded in MVP | Task 06 builds an offline-capable track plot; map tiles deferred | Tile source and usage terms need a decision (public OSM servers forbid bulk download) |
| "Automatic phase detection" in the app | The tracker decides the phase and sends it; app displays it | Keeps the app simple; phase detector is task 11 Part A (pure C++, testable) |
| Device GPS and compass in recovery view | Viewer types in their own lat/lon for now | Permissions differ across six platforms |

### MVP scope (from the brief)

In: tracker firmware (GPS, baro altitude, battery, phase, rocket ID, 1 packet/s); ground node firmware (receives
LoRa, serves packets over its own Wi-Fi); live HUD; live map/track; recovery view (bearing, distance, fix age);
pre-flight profiles and checklist; auto-recorded flights with summary, plots, CSV and KML export; read-only viewers
on the same Wi-Fi (flight board); offline maps; simulator and replay.
Not in MVP: more than three rockets at once, cloud sync or accounts, any control of ignition/deployment,
importing commercial trackers, IREC-grade sensors.

### Design principles (user kept these)

No middlemen; minimal hardware; **the tracker is never flight-critical** (passive telemetry only, never connected to
ejection, ignition or recovery electronics); open protocol and open data; one app on six platforms.

### Success criteria for MVP launch day (proposed numbers, user may adjust)

At least 90% of packets received pad to landing; signal at 3 km or more in a ground range test; HUD updates within
1 s of each packet; three devices watching at once; recovery view gets the crew within 10 m; flight auto-saves and
CSV/KML open in a spreadsheet and Google Earth; simulator demo runs on all six platforms; tracker battery lasts at
least 3 hours; RSO sign-off that the tracker has no connection to recovery or ignition electronics.

## 4. Architecture

```
 [Rocket tracker]  --LoRa 915 MHz, 34-byte packet, 1/s-->  [Ground node]  --Wi-Fi, WebSocket (binary 36-byte frame)-->  [Vector app]
  GPS + baro + battery                                       LoRa receiver,                                              HUD, track, recovery,
  + LoRa radio                                               hosts its own Wi-Fi AP                                      history, export; flights on device
                                                                                   [Simulator] -- same WebSocket ------^
```

- **Why WebSocket over the ground node's Wi-Fi:** Bluetooth and USB serial behave differently on each OS (iOS has no
  generic USB serial). A Wi-Fi WebSocket is identical on all six platforms and allows many viewers at once.
  Caveats: the phone joins a Wi-Fi network with no internet; iOS asks for Local Network permission.
- **App:** Flutter/Dart in `app/` (not yet created). **Firmware:** C++ with PlatformIO and RadioLib (`firmware/`).
  **Maps (later):** flutter_map with pre-downloaded tiles, if the tile-source decision allows.
- Addresses: real ground node (proposed) `ws://192.168.4.1:81`; simulator `ws://localhost:8765`.

### Reference hardware (approximate prices from memory; unverified)

Tracker: LoRa board with SX1262 radio and ESP32-S3 or RP2040 ($15 to $30); u-blox M10-class GPS ($10 to $25, airborne
mode; expect fix loss during boost); barometer BMP390 or MS5611 ($5 to $15); 1S LiPo plus 915 MHz antenna ($10 to $20,
antenna not inside carbon fiber or metal). Ground node: same LoRa board, external antenna ($25 to $45); later a Yagi
($30 to $60). Roughly $65 to $135 total. Radio: 915 MHz LoRa (US ISM band; FCC power limits to be confirmed by the
club; higher power or 70 cm needs an amateur license). Commercial trackers (Altus Metrum TeleGPS, Featherweight) are out
of scope for the MVP, possible future input adapters.

## 5. The protocol (the contract)

Full spec: `protocol/PROTOCOL.md`. Reference implementation: `tools/vector_packet.py`. Never change these without
the user's say-so, and if you do change the protocol, bump the version and regenerate the test data.

Packet: 34 bytes, little-endian, no padding:

| Offset | Size | Field | Type |
| --- | --- | --- | --- |
| 0 | 1 | version (=1) | uint8 |
| 1 | 2 | rocket_id | uint16 |
| 3 | 2 | seq | uint16 (wraps at 65535) |
| 5 | 4 | time_ms (since tracker boot) | uint32 |
| 9 | 4 | lat_e7 | int32 |
| 13 | 4 | lon_e7 | int32 |
| 17 | 4 | gps_alt_cm (MSL) | int32 |
| 21 | 4 | baro_alt_cm (above pad ref) | int32 |
| 25 | 2 | vspeed_cms | int16 (up positive) |
| 27 | 2 | battery_mv | uint16 |
| 29 | 1 | gps_status: low 6 bits sats, high 2 bits fix (0 none, 1 2D, 2 3D, 3 reserved) | uint8 |
| 30 | 1 | phase: 0 pad, 1 boost, 2 coast, 3 apogee, 4 descent, 5 landed | uint8 |
| 31 | 1 | flags: bit0 armed, bit1 low battery | uint8 |
| 32 | 2 | crc16 over bytes 0 to 31 (CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflect, no xorout; check "123456789" = 0x29B1) | uint16 |

Ground frame: 36 bytes = packet + rssi_dbm (int8) + snr_db (int8), one binary WebSocket message per frame.
Receiver check order, reject at first failure: `bad_length`, `bad_crc`, `bad_version`, `bad_phase`. Bad data is counted
and ignored, never a crash. With no GPS fix the tracker repeats the last lat/lon with fix 0 and sats 0; the app must
not draw those as new track points.
Link rules: lost = ((seq - prev_seq) mod 65536) - 1; new session when rocket_id changes, time_ms goes backward, or a
pad packet follows a landed packet; stale after 5 s with no valid frame, lost after 30 s.

Flight statistics (definitions in PROTOCOL.md; reference `tools/flight_stats.py`). For the sample flight the app must
reproduce, within 0.1: apogee 948.5 m, time to apogee 13.0 s, max vertical speed 143.4 m/s, descent rate 6.4 m/s,
flight time 161.0 s, landing distance 619.7 m, 178 packets. Landing is about 76 degrees (east-northeast) from the pad.

### Test data (generated by `python tools/generate_contract_data.py`, never edit by hand)

`protocol/vectors.json` and `vectors.h` ("vectors" means *test vectors*, not the app name), `sample_flight.hex` (178
ground frames, one hex line each), `sample_flight.csv` (the exact CSV format the app's export must reproduce byte for
byte), `expected_stats.json`. `--check` verifies they are current.

### Simulator

`python sim/simulate.py --speed 10` streams the sample flight on `ws://localhost:8765` (waits for a client; `--loop`,
`--no-wait`, `--seed`, `--rocket-id`, `--pad-lat/--pad-lon`). `python sim/listen.py` prints what it sends. The model
is deterministic and not physically exact; it includes the GPS dropout from ignition to 1.5 s after burnout, a short
apogee phase, parachute descent at about 6.5 m/s with wind drift, and 6 packets after landing. **The default pad
coordinates are near Spaceport America (32.99, -106.975), not the club's field. Ask the user for their field's
coordinates.** Dependency: `pip install -r requirements.txt` (websockets 13 or newer).

## 6. What exists and what was verified

| Piece | Where | Status |
| --- | --- | --- |
| Packet reference (Python) | `tools/vector_packet.py` | Done, tested |
| Stats reference | `tools/flight_stats.py` | Done, tested |
| Test-data generator | `tools/generate_contract_data.py` | Done, tested, `--check` passes |
| Flight simulator and listener | `sim/` | Done; verified end to end over a real WebSocket |
| C++ packet library | `firmware/lib/vector_packet/` | Done; 7 native tests pass **with a stand-in Unity shim, not PlatformIO's real Unity** |
| Python tests | `tests/` | **46 pass** (`python -I -m unittest discover -s tests`) |
| One-command checker | `scripts/check.py` | Done; runs Python tests, `flutter analyze` and `flutter test` if `app/pubspec.yaml` exists, `pio test -e native` if `firmware/platformio.ini` and `pio` exist; writes `last_check.txt` |
| Chat-mode helpers | `scripts/bundle.py`, `scripts/apply_reply.py` | Done, tested; written for Open WebUI, **optional now** |
| 12 task files | `tasks/` | Written, **untested**: no Dart or Flutter has been run |
| Docs | `README.md`, `docs/SETUP.md`, `docs/WORKFLOW.md`, `docs/OPENWEBUI.md`, `docs/Modelfile`, `MY_SETUP.md` | Written; Fedora commands unrun on a Fedora machine |
| `app/` | not created | Task 01 |
| Firmware for real boards | not written | Task 11 Part B, blocked on club hardware review |

Renaming: the project was StarTrack, now Vector. C identifiers use the `vx_`/`VX_`/`Vx` prefix (formerly `st_`).
Python modules are `vector_packet`. The kit folder is `vector-kit`. The user asked for "vector" lowercase as the name;
the Flutter package name is `vector`.

## 7. The task plan (details in `tasks/NN_*.md`)

01 create app (`flutter create --project-name vector app`, dark high-contrast theme) · 02 Dart packet decoding against
`vectors.json` · 03 flight statistics against `expected_stats.json` · 04 WebSocket link plus link-health logic ·
05 live HUD · 06 track plot (map tiles deferred) · 07 recording and history (files, `path_provider`, `fl_chart`) ·
08 recovery view (bearing/distance, typed viewer position) · 09 CSV and KML export plus replay · 10 run the firmware
tests under real PlatformIO · 11 Part A phase-detector (pure C++, native tests), Part B boards (STOP, needs club review;
create `docs/HARDWARE_DECISIONS.md`) · 12 settings, wake lock, checklist, `docs/LAUNCH_DAY.md`, `docs/BUILD.md`.
Package allowances per task are stated in each file (for example `web_socket_channel` in 04, `share_plus` in 09).
Proposed pacing from the brief: week 1 tasks 01 to 04, week 2 05 to 07 and order hardware, week 3 08 to 10 and start
11 with a club reviewer, week 4 finish 11, task 12, real flight test.

## 8. Rules to keep (also in `AGENTS.md`)

- Never edit `protocol/`, `tools/`, `sim/`, `tests/` to make a failure go away. If a contract file is wrong,
  fix the generator or reference deliberately, regenerate, and tell the user. Never weaken or delete a test.
- Safety: Vector never controls ignition, ejection or deployment. Do not invent radio settings, frequencies, transmit
  power, pin numbers or battery-charging code; those need a club member's review. Stale data must be shown loudly and
  never as live. Bad data never crashes the app.
- No cloud, accounts, analytics or network calls except to the ground node or simulator.
- Units inside the app: meters, seconds, m/s, degrees; convert at the edge. Times UTC. Large type and high contrast
  (sunlight use).
- `AGENTS.md` was written for a small local model (short rules, one task at a time). It still works for you. Feel free to
  loosen the process parts, but keep the contract and safety parts. `CLAUDE.md` points to this file.

## 9. Lessons from the failed local-model attempt

- Open WebUI exposed built-in tools (`ask_user`, `get_current_timestamp`, `calculate_timestamp`, `create_tasks`,
  `update_task`). Devstral looped on `ask_user` (which errored: "Each question requires 2-3 options"), then on a second
  attempt only ticked off a to-do list and wrote "Task completed" with **no files and no commands**. Nothing was created.
- Fixes already in `scripts/bundle.py`: the preface says "You have NO tools", a `MY_SETUP.md` section answers the platform
  question, and the bundle ends with a "write the FILE: blocks now" instruction. The user had not retried when they
  switched to Claude Code. Do not rely on those paths; build directly.
- Do not re-suggest web search or the code interpreter in Open WebUI; both were advised against.

## 10. Constraints discovered in the cloud sandbox (why the build moved)

The Claude.ai cloud session could not install Flutter: `storage.googleapis.com` and `pub.dev` returned no response and
`github.com` returned 403 through the sandbox proxy. So the Dart code was never compiled or run. On the user's machine
these should work. If they do not, say so and ask the user to paste the error.

## 11. Outstanding questions for the user (ask in plain words, one at a time)

1. What are the club field's latitude and longitude (for the simulator pad and the offline plot)?
2. When is the next club launch where a tracker could fly (the real-flight-test date)?
3. Which LoRa board, GPS, barometer and radio settings does the club want? Who is the reviewing club member (task 11B)?
   Does anyone hold an amateur radio license? What is the parts budget?
4. Who owns the repo and the Apple developer account (about $99/year; needed for iPhone/iPad via TestFlight)?
5. Which devices do members use most (sets platform priority; the brief proposes iPhone and Android first plus one
   desktop, the rest from the same codebase but verified later)?
6. Map tiles: street or satellite, online only or offline packs, and which tile source (terms of use)?
7. Should the brief doc be updated to match the kit (files instead of SQLite, deferred tiles, phase from the tracker)?
8. Which Qwen model do they have and is it worth using at all? (Not needed if Claude Code does the build.)
9. Git: the kit is **not** a git repository. Offer to `git init` and make a first commit so work is saved.

## 12. Next steps (do these in order)

1. Run `python scripts/check.py` and `flutter doctor`; confirm Python passes and the Linux toolchain line is green.
   If Flutter is missing, the Fedora install commands in `docs/SETUP.md` and the chat were:
   `sudo dnf install git curl unzip xz zip which file mesa-libGLU clang cmake ninja-build pkgconf-pkg-config gtk3-devel`,
   `git clone https://github.com/flutter/flutter.git -b stable ~/flutter`, add `$HOME/flutter/bin` to PATH, `flutter doctor`.
   (Package names came from public guides and Flutter's Linux page; not run on Fedora.)
2. Offer to `git init`. Then do **task 01**, run `python scripts/check.py`, have the user run `cd app && flutter run -d linux`
   and confirm a dark window titled Vector reading "Waiting for a rocket". Update `PROGRESS.md`.
3. Continue tasks 02 to 04 (week one), verifying against the contract data with `flutter test` (tests read
   `../protocol/*.json` from `app/`). Then 05 to 09 with the user watching the simulator drive the real screens
   (`python sim/simulate.py --speed 10`).
4. Check the sample-flight numbers and the CSV byte-for-byte test early; they catch most porting mistakes.
5. Task 10 under real PlatformIO (`pip install platformio`, `cd firmware && pio test -e native`). If real Unity disagrees
   with the stand-in, fix the firmware test harness; if numbers disagree with `vectors.h`, stop and investigate.
6. Task 11 Part A, then pause Part B until the club answers question 3.
7. Task 12, including `docs/LAUNCH_DAY.md` and `docs/BUILD.md`. Only claim a platform works if the user ran it.
   Linux can be tested here; macOS, Windows, iOS and Android builds need other machines, so list them honestly as untested.
8. Keep `PROGRESS.md` current and finish each task with a plain-words summary and what the user should see.

## 13. Things that are easy to get wrong

- Signed fields (lat, lon, altitudes, vspeed, rssi, snr) must use signed reads in Dart (`getInt32`, `getInt16`, `getInt8`).
- gps_status: fix type is the **high 2 bits**, satellites the low 6 (`0xFF` = fix 3, 63 sats).
- Stats use the **first** boost packet as launch, the first packet at max `baro_alt_cm` as apogee, and 3D-fix packets only
  for landing distance. `expected_stats.json` values are rounded to 1 decimal; round only at the end.
- The CSV export must equal `protocol/sample_flight.csv` exactly: header, column order, number formats, `\n` endings.
- JSON numbers up to 4294967295 are fine in Dart on native platforms; watch web builds.
- `vectors.json` tests for ground frames use hex strings; remember the invalid ground frames (`ground_invalid`).
- Prices, part numbers and FCC statements in the brief come from memory and were not looked up. Treat them as approximate.

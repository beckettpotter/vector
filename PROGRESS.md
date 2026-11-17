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
- [x] 10 Firmware: packet library check
- [x] 11 Firmware: phase detector now; boards need a club review (Part A only)
- [x] 12 Polish and the launch-day checklist

### Version 2 (plan: `docs/V2_PLAN.md`; build order e, d, f, c, a, b; never ahead of the MVP flight test)

- [x] 13 (v2 e) Dismissible stale-link warning.
  Done when: after 20 s without a packet the STALE/LOST banner has a Dismiss button and an "Auto-hide the warning
  after 20 s" setting (off by default); when hidden, numbers stay greyed as "last known" and a "No link 0:42" chip
  stays visible; the banner comes back on the next outage; stale 5 s and lost 30 s unchanged; tests cover all of it.
- [x] 14 (v2 d) Editable pre-flight checklist with notes.
  Done when: items can be added, edited, deleted (stretch: reordered) and reset to defaults; each item has an optional
  note and there is one general launch notes box; ticks reset each launch while items and notes persist; the checklist
  state and notes are saved in the flight's `.json` and shown in History; broken storage falls back to the defaults.
- [x] 15 (v2 f) Local time display.
  Done when: a "Time zone" setting offers Chicago (default, IANA `America/Chicago`, shown as "Chicago time"), this
  device's zone, from my location (only when location is on) and any zone from a list; History, flight start, notes and
  checklist show local time; everything stored stays UTC; CSV bytes and KML (UTC) are unchanged; tests cover daylight
  saving.
- [x] 16 (v2 c) Optional "Use my location" on every device.
  Done when: a per-device toggle, off by default, shows Vector's own plain explanation before the system prompt; it is
  used only while the app is open, never stored or sent; a refusal shows one calm line and typed entry keeps working;
  a device without location shows "This device can't provide a location"; the Recovery view can use it; Beckett gets
  a plain list of which devices work and how accurately.
- [x] 17 (v2 a) OpenRocket import and projected-vs-actual comparison.
  Done when: the CSV parser follows every rule in the plan and a test on `app/test/fixtures/openrocket_real.csv`
  matches the plan's table (apogee 852.6 m at 10.841 s, and the rest); the Pre-flight Projection card (with the
  optional waiver ceiling and the no-recovery-device and stability wording), the live HUD comparison and chart, and
  the after-flight overlay plots, table, RMS and phase errors and summary all work offline; the projection is saved in
  the flight `.json`; the synthetic, separator, NaN, BOM, header and missing-column tests pass.
- [x] 18 (v2 b) Offline satellite map behind the track plot (USGS, no key, no account).
  Done when: Settings can download a map pack for a field (default Hearne airport, 2/5/10 km, zoom 12 to 16) with
  a size estimate, progress, cancel and delete, politely (2 to 4 requests at once); the Track view draws the stored
  tiles with the USGS credit and imagery dates, makes no network calls at the field, and falls back to the plot with
  one calm line; the honesty note is in Settings; tile-math, counting, storage, fallback and no-network tests pass;
  one real tile request is noted here.

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
- 2026-11-17 (Claude Code on Beckett's Fedora machine): Task 10 done. Installed PlatformIO 6.2.0 with `pip install --user platformio`; `pio test -e native` passed 13 of 13 (7 packet library, 6 phase detector) with the real Unity 2.6.1. `python scripts/check.py` now checks the firmware too when `~/.local/bin` is on PATH. `flutter build linux` also succeeds on this machine.
- Task 11 Part A done: `firmware/lib/phase_detector/` with 6 native tests in `firmware/test/test_phase/` (made-up flight with sequence and change times, pad jitter, low-altitude speed spike, noisy flight, never backwards, 5 s landing streak). They pass with a local stand-in for Unity; they still need a real `pio test -e native` run. Part B: waiting for club review (`docs/HARDWARE_DECISIONS.md`).
- Task 12 done: settings saved across restarts (address, feet/meters, chosen rocket, rocket profiles), screen kept awake while connected, Pre-flight tab (checklist with live values, ticks clear at launch; rocket profiles used to name saved flights; units), friendlier empty and error messages, `docs/LAUNCH_DAY.md`, `docs/BUILD.md`. Network permissions added for Android, iOS and macOS builds (untested). Window title is now "Vector". The brief moved to `docs/BRIEF.md`; `README.md` is now a short project readme.

- v2 plan added (`docs/V2_PLAN.md`) as tasks 13 to 18. Beckett's OpenRocket export and `.ork` are now `app/test/fixtures/openrocket_real.csv` and `app/test/fixtures/journey75.ork` (not used by any test yet; task 17).
- Task 13 (v2 e) done: after 20 s without a packet the banner shows Dismiss; Pre-flight has "Auto-hide the warning after 20 s" (off by default, saved). Dismissed or auto-hidden, a small "No link m:ss" chip stays (amber when stale, red when lost) and tiles keep "last known". The dismissal belongs to that one outage: the next packet re-arms the banner. "20 s" is counted from the last packet, the same number the banner shows. 3 new widget/settings tests. Not yet looked at by eye in the running app.
- Task 14 (v2 d) done: Pre-flight "Edit list" adds, renames, deletes and moves items up/down; "Reset to defaults" (asks first; keeps the launch notes). Each item has a note button; a "Launch notes" box sits under the list. Items and notes are saved on the device (`lib/checklist.dart`); a broken saved list falls back to the five built-in items. Built-in items keep their live hint (armed, GPS, battery, signal) when renamed. At the first boost packet (or a new tracker session) the app keeps a snapshot, then clears the ticks; the snapshot goes into the flight `.json` as `checklist` and `launchNotes`, and the History detail shows it. Older flights without it still load. 6 new tests.
- Task 15 (v2 f) done: Pre-flight "Time zone" setting: Chicago time (default, `America/Chicago`), this device's zone, from my location (falls back to the device zone until task 16 supplies one), or any zone from a searchable list. History, the flight detail and new default flight names show the chosen zone ("2026-12-12 12:00 Chicago time"). Stored times, CSV and KML stay UTC; old flight names keep their "UTC" text. New package: `timezone` (pure Dart, zone data built in, works offline). 5 new tests, including both 2026 daylight-saving changes.
- Task 16 (v2 c) done: Pre-flight "Use my location" switch, per device, off by default (only the on/off choice is saved, never a position). Turning it on shows Vector's own explanation first; the system prompt only follows "Use my location". A no gives one calm line and the switch goes back off; "don't ask again" is respected; no service or no plugin shows "This device can't provide a location right now". Positions are only in memory, stop when the app goes to the background, and are never sent. Uses: Recovery distance and bearing (with "Type my position instead"), a blue YOU dot on the track plot, and the "From my location" time zone (offline lookup, package `lat_lng_to_timezone`, MIT). New packages: `geolocator` 14 (all six platforms) and `lat_lng_to_timezone`. Permission text added for Android, iOS and macOS (untested builds). No compass: the Recovery arrow stays north-up (a compass package would only cover phones). 6 new tests with a pretend location service.
- Which devices give a location (plain words): phones and tablets have GPS, a few meters, works offline at the field. Windows and Mac laptops and desktops: usually no GPS chip, the system guesses from Wi-Fi using the internet, so at a field with no internet expect nothing. This Fedora laptop: GeoClue is set to look up Wi-Fi online (`/etc/geoclue/geoclue.conf`, method ichnaea), so same story; GNOME asks once before Vector gets a location. Not tried with a real position yet.
- Task 17 (v2 a) done. Parser `lib/openrocket/projection.dart` follows every rule in the plan (comment header, events between rows, warnings, NaN, scientific notation, units with non-ASCII and the zero-width space, BOM, comma/semicolon/tab/space, sort out-of-order times, plain-words errors naming the column to tick). On Beckett's real file it gives exactly the plan's table (apogee 852.6 m at 10.841 s, burnout 2.398 s at 348.9 m and 187.5 m/s, 211.2 m/s, 16.8 g, Mach 0.62, descent 12.5 m/s, ground hit 80.078 s, drift 160.7 m toward W, stability -0.41 / -10.5 cal). Predicted descent rate = average over the middle 80% of the fall (apogee to ground hit). Pre-flight "Projection (OpenRocket)": Import CSV (system file dialog; the file is copied into `Vector/projections/`), pick which one the next flight uses, rename, link to a rocket profile (choosing that rocket picks it), delete; the numbers, the no-recovery-device grey labels and one-line fix, OpenRocket's stability number with neutral wording, its warnings, and the optional waiver ceiling in feet (blank by default, silent when blank). HUD: before launch the projection only; after the first boost packet predicted altitude and vertical speed now, the difference, an ABOVE / ON / BELOW PREDICTION chip, a small live chart, and a ±1 s launch nudge in 0.5 s steps. The projection (and nudge) is saved inside the flight `.json`, so History and Replay keep working after the import is deleted. Flight detail: summary sentences from the numbers, table (predicted, actual, difference, %; descent, flight time and landing distance shown as "Simulation has no recovery device" when that applies), RMS altitude error overall and for boost, coast and descent, its own nudge, and real-versus-predicted plots of altitude and vertical speed. New package: `file_picker` 13.3.2 (pinned; 13.4.0 was a day old). 18 new tests. The `.ork` is not read. Stretch (up to three sims as a range) not done. Not yet looked at by eye.
- Task 18 (v2 b) done. USGS terms re-read 2026-11-17: unchanged (public domain, no restrictions, credit requested; nothing about caching or bulk tile fetching). **Real one-tile request, 2026-11-17:** `.../USGSImageryOnly/MapServer/tile/16/26854/15178` (z/y/x) over Hearne returned HTTP 200, a 256x256 JPEG of 16,167 bytes showing the runway; service copyright "USDA, USGS The National Map: Orthoimagery. Data refreshed June, 2024." The airport centre point (AirNav, estimated) is on the runway, so the real launch spot still needs Beckett. Pre-flight, Maps, "Download map for the field": Hearne airport preset (default), pad of this flight, my location, or typed; 2/5/10 km; zoom 12 to 16; tile count and size estimate before starting (at Hearne: 2 km 120 tiles, about 2.4 MB; 5 km 538 tiles, about 11 MB; 10 km 2,087 tiles, about 42 MB, at about 20 KB per tile; 10 km is more than the plan's guess, which said to compute it); progress, cancel, delete; one pack per field. Polite: 3 requests at once, 250 ms pause between batches, User-Agent naming Vector, stored tiles never fetched again, stops after 8 failures in a row, no background syncing. Track tab: Map/Plot switch; the map (`flutter_map` 8.3.2, tiles read from files only, scaled past zoom 16) with rings, path, dashed GPS gaps, pad, rocket, YOU, the USGS credit, "Imagery 2017-2021" and "Imagery limited to about 2 m detail"; with no pack for the area, the plot plus "No map downloaded for this area. Showing the plot." and a download button. Honesty note in the Maps screen. Packs live in `Vector/maps/`. New packages: `flutter_map`, `latlong2`, `http`. 8 new tests (tile math checked against the real request, counts, storage and deletion, politeness, User-Agent, no re-download, stop on errors, cancel, fallback, no network while showing the map, credit, estimate). Looked at by eye once, rendered offscreen with the real Hearne tile. "Tap the map to pick the field" not done (there is no map before the download); a user-supplied tile source is possible later through `TileSource`.
- `docs/LAUNCH_DAY.md` updated for v2 (the night-before map and OpenRocket steps, checklist editing, Dismiss, projection on the HUD, location, Chicago time, a Hearne simulator command).

## Waiting (decisions or things only Beckett can do)

- Try it on the Fedora machine with your own eyes: `python sim/simulate.py --speed 10` in one terminal, `cd app && flutter run -d linux` in another (the app builds on this machine; nobody has clicked through it here yet).
- MVP before v2: the hardware order (Task 11 Part B) and the first real flight test.
- v2 open questions (one at a time, only when needed): exact launch spot on Hearne airport; a re-exported OpenRocket CSV with motor, recovery device and Hearne as launch site; the first flight test date.
- Map tiles: waiting for a decision on street vs satellite and the tile source and its terms.
- Device GPS and compass in Recovery: waiting for a decision (permissions differ per platform).
- Task 11 Part B (tracker and ground-node boards): waiting for club review, see `docs/HARDWARE_DECISIONS.md`.
- Club field coordinates for the simulator (`--pad-lat/--pad-lon`); defaults are near Spaceport America.
- Android, iPhone/iPad, macOS and Windows builds: untested (see `docs/BUILD.md`).

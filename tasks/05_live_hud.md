# Task 05: Live instrument panel (HUD)

## Goal
A big, sunlight-readable screen showing the live flight, driven by the link from task 04.

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` (units and phases).

## Do
1. `app/lib/screens/hud_screen.dart`. Show, in this order, as large tiles:
   - Altitude above the pad (meters, with feet shown smaller), and max altitude so far;
   - Vertical speed (m/s);
   - Flight phase as a word (PAD, BOOST, COAST, APOGEE, DESCENT, LANDED);
   - GPS: fix type and satellite count; when there is no fix show "NO GPS FIX" in the warning color;
   - Battery volts, warning color when the low-battery flag is set;
   - Signal: RSSI and SNR;
   - Time since last packet, always visible.
2. A full-width banner at the top: STALE (no valid frame for 5 s) in amber, LOST (30 s) in red, with the
   seconds count. When stale or lost, grey out the numbers and label them "last known". Never show an old value as live.
3. Max altitude resets when a new session starts (task 04's signal).
4. A switch for feet versus meters, remembered only while the app is open (saving settings is task 12).
5. The home screen shows the Connect box from task 04 above or beside the HUD. Wide screens: two columns.
   Narrow screens (phone): one column that scrolls.
6. Widget tests in `app/test/hud_test.dart` with hand-made frames: live values appear, "NO GPS FIX" appears with
   fix type 0, the stale banner appears at 6 s, "last known" appears when stale.

## Do not
Add a map, charts or recording. Use only the colors and sizes from `theme.dart` (add named colors there if needed).

## Done when
`python scripts/check.py` passes. With `sim/simulate.py --speed 5` running, the person watches altitude climb to
about 950 m, the GPS warning appear during boost, and the phase change through all six words.

## Then
Tick task 05. Ask the person for a screenshot of the HUD if their tool supports it, and note any readability complaint in `PROGRESS.md`.

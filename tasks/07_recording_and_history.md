# Task 07: Flight recording and history

## Goal
Every flight is saved automatically as plain files, and the person can browse past flights and see their summary.

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` ("Link rules" and "Flight statistics").

## Do
1. Add packages: `path_provider` (app documents folder) and `fl_chart` (altitude and speed plots). No others.
2. `app/lib/storage/flight_store.dart`: a flight is two files in a `flights/` folder inside the app documents
   folder: `flight_<rocketId>_<yyyyMMdd_HHmmss>.hex` (one ground frame as hex per line, the same format as
   `protocol/sample_flight.hex`) and a matching `.json` with `{name, rocketId, startedAtUtc, padLat, padLon, notes}`.
   Methods: start a flight, append a frame (write to disk immediately so a crash loses at most one packet),
   finish, list flights (newest first), load a flight, rename, delete (ask for confirmation in the UI).
3. A recorder that listens to the link: a flight starts on the first `boost` packet **or** the first `pad` packet
   after a gap (keep the last 30 pad packets in memory so the pad period is saved too), ends 15 s after
   `landed` or when the link is lost for 30 s, and starts a new file on any new-session signal. A flight with
   fewer than 10 packets is discarded.
4. `app/lib/screens/history_screen.dart`: a list of flights (name, date, apogee). Tapping one opens a detail
   screen with the six statistics from task 03 (meters, feet shown smaller), an altitude plot and a speed plot,
   and rename/delete.
5. Tests in `app/test/flight_store_test.dart` using a temporary folder: write the sample flight, list it, load it,
   and check the loaded stats equal `expected_stats.json`. Also test discard of a short flight and crash-safety
   (every appended frame is on disk before the next one).

## Do not
Use a database. Do not upload anything anywhere. Do not change the hex format.

## Done when
`python scripts/check.py` passes. The person runs one full simulated flight, finds it in History with apogee
948.5 m, and sees the plots. Quitting and reopening the app still shows it.

## Then
Tick task 07. Tell the person where the flight files are stored on their computer.

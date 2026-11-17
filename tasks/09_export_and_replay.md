# Task 09: Export and replay

## Goal
Flights can be exported to CSV and KML, shared, and replayed in the app as if they were live.

## Read first
`AGENTS.md`, `protocol/sample_flight.csv` (the exact CSV format), `protocol/PROTOCOL.md`.

## Do
1. `app/lib/storage/export.dart`, pure Dart:
   - `String flightToCsv(List<GroundFrame>)`: **byte-for-byte identical** to `protocol/sample_flight.csv`
     for the sample flight (same header, column order, number formats, `\n` line endings, trailing newline).
   - `String flightToKml(List<GroundFrame>, String name)`: valid KML with a `LineString` of the 3D-fix track
     (coordinates are `longitude,latitude,altitude` in that order, altitude in meters above sea level), a
     placemark for the pad and one for the landing spot.
2. Tests in `app/test/export_test.dart`: the CSV equals `../protocol/sample_flight.csv` exactly; the KML
   parses as XML, has the pad and landing placemarks, and its first coordinate is the pad as lon,lat,alt.
3. Add the package `share_plus`. On the flight detail screen add Export CSV and Export KML buttons that write
   the file and open the system share sheet (or save dialog on desktop).
4. Import and replay: `app/lib/link/replay_link.dart` plays a `.hex` file as if it were a live link, at 1x, 5x
   or 10x. It must feed the same frame stream and link monitor the real link uses, so the HUD, track and recovery
   screens work unchanged. Add a "Replay a flight" choice in History (replay a saved flight, no file picker needed)
   and a play/pause control and a scrub slider.
5. A test that replays the sample flight at high speed and checks the final frame count and last phase.

## Do not
Change the CSV format to make it "nicer". The test file is the source of truth.

## Done when
`python scripts/check.py` passes. The person exports the simulated flight, opens the CSV in a spreadsheet and the
KML in Google Earth (or earth.google.com), and replays it through the HUD.

## Then
Tick task 09.

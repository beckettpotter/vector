# Task 03: Flight statistics

## Goal
Pure Dart code that computes the flight summary from a list of packets, matching the reference numbers.

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` section "Flight statistics", `tools/flight_stats.py`,
`protocol/expected_stats.json`.

## Do
1. `app/lib/protocol/flight_stats.dart`:
   - `double haversineM(double lat1, double lon1, double lat2, double lon2)` (Earth radius 6371000 m).
   - `class FlightStats` with `apogeeM`, `timeToApogeeS`, `maxVerticalSpeedMs`, `descentRateMs`,
     `flightTimeS`, `landingDistanceM`, `packetCount`.
   - `FlightStats computeStats(List<Packet> packets)`. Throw a clear `StateError` if the flight has no boost
     packet or no landed packet. Follow the definitions in the spec exactly (first boost packet, first apogee
     tie wins, only 3D-fix packets for distance, and so on).
2. `app/lib/protocol/flight_file.dart`: `List<GroundFrame> parseHexFlight(String text)` that reads the
   format of `protocol/sample_flight.hex` (one frame as hex per line; ignore blank lines).
3. `app/test/stats_test.dart`:
   - haversine: (0,0)-(0,0) is 0, and (0,0)-(1,0) is 111194.9 within 1 m;
   - load `../protocol/sample_flight.hex`, parse it, compute stats, and compare every value with
     `../protocol/expected_stats.json` within 0.1 (packet count exactly);
   - a flight with no landed packet throws.

## Do not
Edit `protocol/`. Round only at the end (the expected values are rounded to 1 decimal).

## Done when
`python scripts/check.py` passes.

## Then
Tick task 03. Tell the person the six numbers the sample flight produces.

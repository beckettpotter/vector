# Task 06: Track plot (and map later)

## Goal
A picture of where the rocket went and where it is now. This task builds a **track plot that needs no
internet**. Map tiles are a separate decision (see "Stop and ask").

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` (the paragraph about repeated positions when there is no GPS fix).

## Do
1. `app/lib/screens/track_screen.dart`: a `CustomPainter` plot, north up, auto-scaled, with:
   - the pad (a marker at the first 3D-fix position of the session);
   - the flight path as a line through only the packets that have a 3D fix (never draw the repeated
     positions from boost as new points; show a dashed straight line across the gap instead);
   - the rocket's latest position as a bright dot, colored by phase;
   - distance rings (100 m, 250 m, 500 m, 1 km, 2 km as scale needs) with labels, and a north arrow;
   - a "last known position, age Ns" label that appears when GPS is lost.
2. `app/lib/storage/` is not used yet. Keep the track in memory for the current session; clear it on a new session.
3. Put the pure math (meters east/north of the pad from lat/lon, using a flat-earth approximation that is fine
   within 10 km; scale choice; ring spacing) in `app/lib/protocol/geo.dart` with tests in `app/test/geo_test.dart`
   (for example: 0.001 degrees of latitude is about 111.2 m north; longitude shrinks by the cosine of latitude).
4. A tab or button on the home screen switches between the HUD and the track plot.
5. A widget test that feeds the sample flight (`protocol/sample_flight.hex`) and checks the painter does not
   throw and that the gap packets are excluded from the path points.

## Stop and ask (do not do this yourself)
Real map tiles, especially offline ones, need a decision about tile source and usage terms (the public
OpenStreetMap servers forbid bulk downloads). If the person asks for a street/satellite map, stop and tell them to
ask Claude. Add a line to `PROGRESS.md`: "Map tiles: waiting for Claude".

## Done when
`python scripts/check.py` passes. With the simulator running, the person sees the pad, a path drifting east-northeast,
the dashed gap during boost, and the dot drifting to the landing spot about 620 m from the pad.

## Then
Tick task 06.

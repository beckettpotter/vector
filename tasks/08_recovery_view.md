# Task 08: Recovery view

## Goal
After the rocket lands, tell the recovery crew which way to walk and how far, using the last known position.

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` (repeated positions when GPS has no fix).

## Do
1. `app/lib/protocol/navigation.dart`, pure Dart:
   - `double bearingDeg(lat1, lon1, lat2, lon2)`: initial bearing, 0 to 360, 0 is north, clockwise;
   - `String cardinal(double deg)`: N, NE, E, SE, S, SW, W, NW;
   - reuse `haversineM` from task 03 for distance.
   - `lastKnownFix(List<Packet>)`: the most recent packet with a 3D fix, and how old it is.
2. `app/test/navigation_test.dart` with known answers: due north is 0, due east is 90, due south is 180,
   due west is 270; (0,0) to (0,1) is about 111195 m at bearing 90; cardinals at the edges (22.4 and 22.6 degrees).
3. `app/lib/screens/recovery_screen.dart`:
   - Large text: distance (m, with ft smaller), bearing in degrees and cardinal letters, and an arrow drawn
     rotated to the bearing (north-up arrow; no compass sensor yet).
   - The rocket's last known coordinates in decimal degrees, a "Copy coordinates" button, and the age of that fix.
   - "Your position": two number fields where the person can type their latitude and longitude. Pre-fill them with
     the pad position. Mark clearly that GPS from the device is not used yet.
   - When the rocket is still in flight, show the same data but label it "rocket still flying".
4. A third tab on the home screen for Recovery.

## Stop and ask
Reading the device's own GPS and compass needs platform permissions that differ on iPhone, Android and desktop.
Do not add it. Add the line "Device GPS and compass: waiting for Claude" to `PROGRESS.md`.

## Done when
`python scripts/check.py` passes. After a simulated flight lands, Recovery shows about 620 m and a bearing of about 76 degrees (ENE)
 from the pad position typed in as the viewer.

## Then
Tick task 08.

# Task 12: Polish and the launch-day checklist

## Goal
Make the app dependable at the field, and write down how to run launch day.

## Read first
`AGENTS.md`, `PROGRESS.md`, and every note in it marked "waiting for Claude".

## Do
1. Settings that survive restarts: address of the ground node, meters or feet, last rocket name. Use the package
   `shared_preferences`. Wrap reads so a failure falls back to defaults and never crashes.
2. Keep the screen awake while connected: package `wakelock_plus`. Release it when disconnected.
3. A big, friendly empty state and a clear message for each failure: cannot reach the address (and what to check),
   connected but no packets yet, and the simulator address versus the real one.
4. A rocket profile screen (name, motor, mass, tracker id, notes) used to name saved flights.
5. A pre-flight checklist screen with tickable items: tracker armed, GPS fix on the pad, battery above 3.7 V,
   signal check (shows live RSSI), club RSO approval. Ticks reset each launch.
6. `docs/LAUNCH_DAY.md`: a one-page procedure the club can print: what to bring (ground node, power bank, devices),
   how to power on, how to join the ground node's Wi-Fi (and that phones may warn "no internet"), how to connect the app,
   the pre-flight checklist, what each warning means, and what to do if the link goes stale or lost.
7. `docs/BUILD.md`: the exact command to build each platform that has been tested, and which have not been tested yet.
8. Run `python scripts/check.py` and fix everything.

## Do not
Add features that are not here. Do not claim a platform works unless the person ran it.

## Done when
`python scripts/check.py` passes, the settings survive an app restart, and `docs/LAUNCH_DAY.md` and `docs/BUILD.md` exist.

## Then
Tick task 12. List for the person every note in `PROGRESS.md` that still says "waiting for Claude".

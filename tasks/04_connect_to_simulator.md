# Task 04: Connect to the simulator

## Goal
The app connects to a WebSocket (the simulator now, the real ground node later), decodes every frame,
and keeps link-health numbers. No new screens except a minimal Connect box.

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` sections "Rules for receivers" and "Link rules".

## Do
1. Add the package `web_socket_channel` (the only new package allowed).
2. `app/lib/link/link_monitor.dart`: pure logic, no network, no Flutter. It takes a clock function so tests
   can control time. It receives decoded `GroundFrame`s and rejected-frame events, and exposes:
   - latest frame, frame count, rejected count;
   - lost packets, using `lost = ((seq - previousSeq) mod 65536) - 1` per rocket;
   - `status` at a given time: `waiting` (never got a frame), `live`, `stale` (no valid frame for 5 s),
     `lost` (30 s);
   - `sinceLastMs`;
   - a "new session" signal when the rocket id changes, when `timeMs` goes backward, or when a pad packet
     follows a landed packet.
3. `app/lib/link/ws_link.dart`: connects to an address, feeds binary messages to `decodeGroundFrame`,
   counts and ignores text messages and bad frames (never crash), and reconnects with a 1 s then 2 s then 5 s
   back-off while the person has not pressed Disconnect. It exposes a `Stream` of frames and the connection state.
4. A minimal Connect box on the home screen: an address field (default `ws://localhost:8765`), a
   Connect/Disconnect button, and plain text showing: connection state, frames received, rejected, lost, and
   time since last frame, updating live.
5. `app/test/link_monitor_test.dart`: test every rule above with a fake clock (wraparound of `seq` 65535 to 0,
   stale at 5 s, lost at 30 s, each new-session case).

## Do not
Build the instrument panel yet. Do not retry in a tight loop.

## Done when
- `python scripts/check.py` passes.
- The person runs `python sim/simulate.py --speed 10` and the app. After pressing Connect, the frame count climbs to
  178 and the status is live. When the simulator finishes, the status becomes stale after 5 s, then lost.

## Then
Tick task 04. Tell the person what they should see.

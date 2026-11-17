"""Flight simulator: streams a simulated flight over a WebSocket.

It behaves like the real ground node will: every message is one binary
36-byte "ground frame" (34-byte packet + rssi + snr), one per second.

    pip install -r requirements.txt           # once
    python sim/simulate.py                    # real time, waits for the app to connect
    python sim/simulate.py --speed 10         # ten times faster (good while developing)
    python sim/simulate.py --loop             # fly again and again

Then point the app at  ws://<this computer's address>:8765
To watch the stream without the app:   python sim/listen.py
"""
from __future__ import annotations

import argparse
import asyncio
import socket
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

from flight_model import DEFAULT_PAD_LAT, DEFAULT_PAD_LON, FlightParams, generate_flight  # noqa: E402
from vector_packet import encode_ground_frame  # noqa: E402


async def serve_flight(frames: list[bytes], host: str = "0.0.0.0", port: int = 8765,
                       speed: float = 1.0, loop: bool = False, wait_for_client: bool = True,
                       on_listening=None, pause_between_s: float = 5.0) -> None:
    """Broadcast `frames` (a list of bytes) to every connected client, one per second / speed."""
    from websockets.asyncio.server import broadcast, serve

    clients: set = set()
    first_client = asyncio.Event()

    async def handler(ws):
        clients.add(ws)
        first_client.set()
        try:
            await ws.wait_closed()
        finally:
            clients.discard(ws)

    async with serve(handler, host, port) as server:
        actual_port = server.sockets[0].getsockname()[1]
        if on_listening:
            on_listening(actual_port)
        if wait_for_client:
            await first_client.wait()
        while True:
            for data in frames:
                broadcast(clients, data)
                await asyncio.sleep(1.0 / speed)
            if not loop:
                break
            await asyncio.sleep(pause_between_s / speed)
        await asyncio.sleep(0.5)  # let the last frame go out before closing


def _lan_address() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))  # no traffic is sent
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def main() -> int:
    ap = argparse.ArgumentParser(description="Vector flight simulator")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--speed", type=float, default=1.0, help="1 = real time, 10 = ten times faster")
    ap.add_argument("--loop", action="store_true", help="repeat the flight forever")
    ap.add_argument("--no-wait", action="store_true", help="start at once instead of waiting for a client")
    ap.add_argument("--rocket-id", type=int, default=1)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--pad-lat", type=float, default=DEFAULT_PAD_LAT)
    ap.add_argument("--pad-lon", type=float, default=DEFAULT_PAD_LON)
    args = ap.parse_args()
    if args.speed <= 0:
        ap.error("--speed must be above 0")

    params = FlightParams(rocket_id=args.rocket_id, seed=args.seed,
                          pad_lat=args.pad_lat, pad_lon=args.pad_lon)
    frames = [encode_ground_frame(f) for f in generate_flight(params)]

    def announce(port: int) -> None:
        print(f"Simulator ready: {len(frames)} packets, 1 per second at speed x{args.speed:g}.")
        print(f"  On this computer:   ws://localhost:{port}")
        print(f"  From another device: ws://{_lan_address()}:{port}")
        print("Waiting for the app to connect... (Ctrl+C to stop)" if not args.no_wait
              else "Streaming now... (Ctrl+C to stop)")

    try:
        asyncio.run(serve_flight(frames, port=args.port, speed=args.speed, loop=args.loop,
                                 wait_for_client=not args.no_wait, on_listening=announce))
    except KeyboardInterrupt:
        print("\nStopped.")
    except ImportError:
        print("The 'websockets' library is missing. Run:  pip install -r requirements.txt")
        return 1
    print("Flight finished." if not args.loop else "")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

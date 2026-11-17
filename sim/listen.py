"""Print what a Vector WebSocket stream is sending, so you can check it
without the app.

    python sim/listen.py                       # connects to ws://localhost:8765
    python sim/listen.py ws://192.168.4.1:81   # any other address
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

from vector_packet import PHASE_NAMES, PacketError, decode_ground_frame  # noqa: E402


async def listen(url: str) -> None:
    from websockets.asyncio.client import connect
    from websockets.exceptions import ConnectionClosed

    print(f"Connecting to {url} ...")
    async with connect(url) as ws:
        print("Connected. Waiting for packets.\n")
        print(f"{'seq':>4} {'phase':<8} {'alt m':>8} {'vs m/s':>7} {'fix':>3} {'sats':>4} "
              f"{'batt mV':>7} {'rssi':>5} {'snr':>4}")
        try:
            async for message in ws:
                try:
                    f = decode_ground_frame(message)
                except PacketError as exc:
                    print(f"  rejected a bad frame ({exc.code})")
                    continue
                p = f.packet
                print(f"{p.seq:>4} {PHASE_NAMES[p.phase]:<8} {p.baro_alt_m:>8.1f} {p.vspeed_ms:>7.1f} "
                      f"{p.fix_type:>3} {p.sats:>4} {p.battery_mv:>7} {f.rssi_dbm:>5} {f.snr_db:>4}")
        except ConnectionClosed:
            pass
    print("\nStream ended.")


if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else "ws://localhost:8765"
    try:
        asyncio.run(listen(url))
    except KeyboardInterrupt:
        pass
    except OSError as exc:
        print(f"Could not connect: {exc}")
        raise SystemExit(1)

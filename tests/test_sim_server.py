import asyncio
import unittest

import _paths  # noqa: F401
from flight_model import generate_flight
from simulate import serve_flight
from vector_packet import GROUND_FRAME_SIZE, decode_ground_frame, encode_ground_frame


class SimServerTests(unittest.IsolatedAsyncioTestCase):
    async def test_client_receives_the_whole_flight_in_order(self):
        from websockets.asyncio.client import connect

        frames = [encode_ground_frame(f) for f in generate_flight()][:30]
        loop = asyncio.get_running_loop()
        port_future = loop.create_future()
        server_task = asyncio.create_task(serve_flight(
            frames, host="127.0.0.1", port=0, speed=200.0,
            on_listening=lambda p: port_future.set_result(p)))
        port = await asyncio.wait_for(port_future, 5)

        received = []
        async with connect(f"ws://127.0.0.1:{port}") as ws:
            async for message in ws:
                received.append(message)
        await asyncio.wait_for(server_task, 10)

        self.assertEqual(len(received), len(frames))
        for sent, got in zip(frames, received):
            self.assertIsInstance(got, bytes)
            self.assertEqual(len(got), GROUND_FRAME_SIZE)
            self.assertEqual(got, sent)
        self.assertEqual([decode_ground_frame(m).packet.seq for m in received], list(range(30)))


if __name__ == "__main__":
    unittest.main()

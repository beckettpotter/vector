import json
import unittest

import _paths  # noqa: F401
from vector_packet import (
    GROUND_FRAME_SIZE, PACKET_SIZE, GroundFrame, Packet, PacketError,
    crc16_ccitt_false, decode, decode_ground_frame, encode, encode_ground_frame,
)

VECTORS = json.loads((_paths.ROOT / "protocol" / "vectors.json").read_text())


def _hand_built_packet() -> bytes:
    """Built byte by byte WITHOUT struct, so it checks the layout independently."""
    body = b"".join([
        (1).to_bytes(1, "little"),                       # version
        (0x1234).to_bytes(2, "little"),                  # rocket_id
        (0x0102).to_bytes(2, "little"),                  # seq
        (0x0A0B0C0D).to_bytes(4, "little"),              # time_ms
        (-1).to_bytes(4, "little", signed=True),         # lat_e7
        (2).to_bytes(4, "little", signed=True),          # lon_e7
        (3).to_bytes(4, "little", signed=True),          # gps_alt_cm
        (-4).to_bytes(4, "little", signed=True),         # baro_alt_cm
        (-5).to_bytes(2, "little", signed=True),         # vspeed_cms
        (4100).to_bytes(2, "little"),                    # battery_mv
        bytes([(2 << 6) | 9]),                           # gps_status: fix 2, 9 satellites
        bytes([3]),                                      # phase: apogee
        bytes([1]),                                      # flags: armed
    ])
    return body + crc16_ccitt_false(body).to_bytes(2, "little")


class CrcTests(unittest.TestCase):
    def test_standard_check_value(self):
        self.assertEqual(crc16_ccitt_false(b"123456789"), 0x29B1)

    def test_vector_file_agrees(self):
        self.assertEqual(VECTORS["crc_check"]["crc16_ccitt_false"], "0x29B1")


class PacketTests(unittest.TestCase):
    def test_sizes(self):
        self.assertEqual(PACKET_SIZE, 34)
        self.assertEqual(GROUND_FRAME_SIZE, 36)

    def test_layout_matches_hand_built_bytes(self):
        pkt = Packet(rocket_id=0x1234, seq=0x0102, time_ms=0x0A0B0C0D, lat_e7=-1, lon_e7=2,
                     gps_alt_cm=3, baro_alt_cm=-4, vspeed_cms=-5, battery_mv=4100,
                     sats=9, fix_type=2, phase=3, flags=1)
        self.assertEqual(encode(pkt), _hand_built_packet())
        self.assertEqual(decode(_hand_built_packet()), pkt)

    def test_round_trip_every_valid_vector(self):
        for v in VECTORS["valid"]:
            with self.subTest(v["name"]):
                pkt = Packet(**v["fields"])
                self.assertEqual(encode(pkt).hex(), v["hex"])
                self.assertEqual(decode(bytes.fromhex(v["hex"])), pkt)

    def test_every_invalid_vector_is_rejected_with_its_code(self):
        for v in VECTORS["invalid"]:
            with self.subTest(v["name"]):
                with self.assertRaises(PacketError) as ctx:
                    decode(bytes.fromhex(v["hex"]))
                self.assertEqual(ctx.exception.code, v["error"])

    def test_gps_status_byte_packs_fix_and_sats(self):
        data = encode(Packet(sats=63, fix_type=3))
        self.assertEqual(data[29], 0xFF)
        data = encode(Packet(sats=5, fix_type=1))
        self.assertEqual(data[29], 0x45)

    def test_encode_rejects_out_of_range_fields(self):
        for bad in (Packet(sats=64), Packet(fix_type=4), Packet(rocket_id=70000),
                    Packet(vspeed_cms=40000)):
            with self.subTest(bad):
                with self.assertRaises(PacketError):
                    encode(bad)


class GroundFrameTests(unittest.TestCase):
    def test_valid_ground_frames(self):
        packets = {v["name"]: Packet(**v["fields"]) for v in VECTORS["valid"]}
        for g in VECTORS["ground_valid"]:
            with self.subTest(g["name"]):
                frame = decode_ground_frame(bytes.fromhex(g["hex"]))
                self.assertEqual(frame.packet, packets[g["packet"]])
                self.assertEqual(frame.rssi_dbm, g["rssi_dbm"])
                self.assertEqual(frame.snr_db, g["snr_db"])
                self.assertEqual(encode_ground_frame(frame).hex(), g["hex"])

    def test_invalid_ground_frames(self):
        for g in VECTORS["ground_invalid"]:
            with self.subTest(g["name"]):
                with self.assertRaises(PacketError) as ctx:
                    decode_ground_frame(bytes.fromhex(g["hex"]))
                self.assertEqual(ctx.exception.code, g["error"])

    def test_radio_bytes_are_signed(self):
        data = encode_ground_frame(GroundFrame(Packet(), -128, -1))
        self.assertEqual(data[34], 0x80)
        self.assertEqual(data[35], 0xFF)


if __name__ == "__main__":
    unittest.main()

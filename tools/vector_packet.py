"""Vector packet reference implementation (Python).

The wire format is defined in protocol/PROTOCOL.md. This file is the
reference implementation of it. The Dart app and the C++ firmware must
match it byte for byte, and are checked against protocol/vectors.json.

No third-party libraries are needed.
"""
from __future__ import annotations

import struct
from dataclasses import dataclass

PROTOCOL_VERSION = 1
PACKET_SIZE = 34          # bytes sent over the LoRa radio
GROUND_FRAME_SIZE = 36    # packet + rssi + snr, sent over the WebSocket

# 32 bytes of body, little-endian, no padding. The CRC (2 bytes) follows.
_BODY = struct.Struct("<BHHIiiiihHBBB")
_RADIO = struct.Struct("<bb")

PHASE_PAD = 0
PHASE_BOOST = 1
PHASE_COAST = 2
PHASE_APOGEE = 3
PHASE_DESCENT = 4
PHASE_LANDED = 5
PHASE_NAMES = ["pad", "boost", "coast", "apogee", "descent", "landed"]

FIX_NONE = 0
FIX_2D = 1
FIX_3D = 2

FLAG_ARMED = 0x01
FLAG_LOW_BATTERY = 0x02


class PacketError(ValueError):
    """Raised for any packet that must be rejected. `code` is one of
    bad_length, bad_crc, bad_version, bad_phase, bad_field."""

    def __init__(self, code: str, message: str = ""):
        super().__init__(f"{code}: {message}" if message else code)
        self.code = code


def crc16_ccitt_false(data: bytes) -> int:
    """CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, no xorout.
    Check value: crc16_ccitt_false(b"123456789") == 0x29B1."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


@dataclass(frozen=True)
class Packet:
    version: int = PROTOCOL_VERSION
    rocket_id: int = 0
    seq: int = 0
    time_ms: int = 0
    lat_e7: int = 0          # degrees * 10^7
    lon_e7: int = 0          # degrees * 10^7
    gps_alt_cm: int = 0      # centimeters above sea level
    baro_alt_cm: int = 0     # centimeters above the pad reference
    vspeed_cms: int = 0      # centimeters per second, up is positive
    battery_mv: int = 0
    sats: int = 0            # 0..63
    fix_type: int = 0        # 0 none, 1 2D, 2 3D, 3 reserved
    phase: int = 0           # 0..5, see PHASE_NAMES
    flags: int = 0           # bit0 armed, bit1 low battery

    @property
    def armed(self) -> bool:
        return bool(self.flags & FLAG_ARMED)

    @property
    def low_battery(self) -> bool:
        return bool(self.flags & FLAG_LOW_BATTERY)

    @property
    def has_3d_fix(self) -> bool:
        return self.fix_type >= FIX_3D

    @property
    def lat_deg(self) -> float:
        return self.lat_e7 / 1e7

    @property
    def lon_deg(self) -> float:
        return self.lon_e7 / 1e7

    @property
    def baro_alt_m(self) -> float:
        return self.baro_alt_cm / 100.0

    @property
    def vspeed_ms(self) -> float:
        return self.vspeed_cms / 100.0


@dataclass(frozen=True)
class GroundFrame:
    packet: Packet
    rssi_dbm: int
    snr_db: int


def encode(p: Packet) -> bytes:
    """Packet -> 34 bytes."""
    if not 0 <= p.sats <= 63:
        raise PacketError("bad_field", "sats must be 0..63")
    if not 0 <= p.fix_type <= 3:
        raise PacketError("bad_field", "fix_type must be 0..3")
    gps_status = (p.fix_type << 6) | p.sats
    try:
        body = _BODY.pack(
            p.version, p.rocket_id, p.seq, p.time_ms,
            p.lat_e7, p.lon_e7, p.gps_alt_cm, p.baro_alt_cm,
            p.vspeed_cms, p.battery_mv, gps_status, p.phase, p.flags,
        )
    except struct.error as exc:
        raise PacketError("bad_field", str(exc)) from exc
    crc = crc16_ccitt_false(body)
    return body + struct.pack("<H", crc)


def decode(data: bytes) -> Packet:
    """34 bytes -> Packet. Checks run in this order: length, CRC, version, phase."""
    if len(data) != PACKET_SIZE:
        raise PacketError("bad_length", f"expected {PACKET_SIZE} bytes, got {len(data)}")
    body, (crc_in,) = data[:32], struct.unpack("<H", data[32:])
    if crc16_ccitt_false(body) != crc_in:
        raise PacketError("bad_crc")
    (version, rocket_id, seq, time_ms, lat, lon, gps_alt, baro_alt,
     vspeed, battery, gps_status, phase, flags) = _BODY.unpack(body)
    if version != PROTOCOL_VERSION:
        raise PacketError("bad_version", f"got version {version}")
    if phase > PHASE_LANDED:
        raise PacketError("bad_phase", f"got phase {phase}")
    return Packet(
        version=version, rocket_id=rocket_id, seq=seq, time_ms=time_ms,
        lat_e7=lat, lon_e7=lon, gps_alt_cm=gps_alt, baro_alt_cm=baro_alt,
        vspeed_cms=vspeed, battery_mv=battery,
        sats=gps_status & 0x3F, fix_type=gps_status >> 6,
        phase=phase, flags=flags,
    )


def encode_ground_frame(frame: GroundFrame) -> bytes:
    """GroundFrame -> 36 bytes (34-byte packet, then rssi int8, then snr int8)."""
    try:
        radio = _RADIO.pack(frame.rssi_dbm, frame.snr_db)
    except struct.error as exc:
        raise PacketError("bad_field", str(exc)) from exc
    return encode(frame.packet) + radio


def decode_ground_frame(data: bytes) -> GroundFrame:
    if len(data) != GROUND_FRAME_SIZE:
        raise PacketError("bad_length", f"expected {GROUND_FRAME_SIZE} bytes, got {len(data)}")
    packet = decode(data[:PACKET_SIZE])
    rssi, snr = _RADIO.unpack(data[PACKET_SIZE:])
    return GroundFrame(packet=packet, rssi_dbm=rssi, snr_db=snr)

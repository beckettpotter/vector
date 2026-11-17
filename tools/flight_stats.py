"""Reference flight statistics, computed only from decoded packets.

The Dart app must produce the same numbers (see tasks/03 and
protocol/expected_stats.json). The exact definitions are in
protocol/PROTOCOL.md under "Flight statistics".
"""
from __future__ import annotations

import math

from vector_packet import (
    FIX_3D, PHASE_BOOST, PHASE_DESCENT, PHASE_LANDED, Packet,
)

EARTH_RADIUS_M = 6371000.0


def haversine_m(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
    """Great-circle distance in meters on a sphere of radius 6371000 m."""
    p1, p2 = math.radians(lat1_deg), math.radians(lat2_deg)
    dphi = p2 - p1
    dlmb = math.radians(lon2_deg - lon1_deg)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def compute_stats(packets: list[Packet]) -> dict:
    """Return the flight summary. Values are rounded as in the spec:
    meters and m/s to 1 decimal place, seconds to 1 decimal place."""
    launch = next((p for p in packets if p.phase == PHASE_BOOST), None)
    landed = next((p for p in packets if p.phase == PHASE_LANDED), None)
    if launch is None or landed is None:
        raise ValueError("flight has no boost packet or no landed packet")

    peak = packets[0]
    for p in packets:
        if p.baro_alt_cm > peak.baro_alt_cm:   # first packet wins a tie
            peak = p

    fixes = [p for p in packets if p.fix_type >= FIX_3D]
    pad_fix = fixes[0]
    last_fix = [p for p in fixes if p.phase == PHASE_LANDED][-1]
    descent = [p for p in packets if p.phase == PHASE_DESCENT]

    return {
        "apogee_m": round(peak.baro_alt_cm / 100.0, 1),
        "time_to_apogee_s": round((peak.time_ms - launch.time_ms) / 1000.0, 1),
        "max_vertical_speed_ms": round(max(abs(p.vspeed_cms) for p in packets) / 100.0, 1),
        "descent_rate_ms": round(-sum(p.vspeed_cms for p in descent) / len(descent) / 100.0, 1),
        "flight_time_s": round((landed.time_ms - launch.time_ms) / 1000.0, 1),
        "landing_distance_m": round(
            haversine_m(pad_fix.lat_deg, pad_fix.lon_deg, last_fix.lat_deg, last_fix.lon_deg), 1),
        "packet_count": len(packets),
    }

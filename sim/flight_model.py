"""A simple, deterministic L1-class flight model that produces Vector packets.

It is NOT a physics-accurate rocket simulation. It exists so the app can be
built and demoed without a rocket. It deliberately includes the awkward
things a real flight does:
  * the GPS loses its fix during boost and re-acquires in coast,
  * a short "apogee" phase,
  * a slow parachute descent with wind drift,
  * a few packets after landing.

Same seed + same parameters = same flight, every time.
"""
from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

from flight_stats import haversine_m  # noqa: E402
from vector_packet import (  # noqa: E402
    FIX_3D, FIX_NONE, FLAG_ARMED, PHASE_APOGEE, PHASE_BOOST, PHASE_COAST,
    PHASE_DESCENT, PHASE_LANDED, PHASE_PAD, GroundFrame, Packet,
)

# Approximate location of Spaceport America (home of IREC). Change it with
# --pad-lat / --pad-lon on the simulator to put the pad at your own field.
DEFAULT_PAD_LAT = 32.9900
DEFAULT_PAD_LON = -106.9750

G = 9.80665
M_PER_DEG_LAT = 111_320.0


@dataclass(frozen=True)
class FlightParams:
    rocket_id: int = 1
    seed: int = 1
    pad_lat: float = DEFAULT_PAD_LAT
    pad_lon: float = DEFAULT_PAD_LON
    pad_msl_m: float = 1400.0
    pad_wait_s: float = 10.3       # time on the pad before ignition
    thrust_accel: float = 95.0     # m/s^2 while the motor burns (before gravity and drag)
    burn_s: float = 2.0
    drag_k: float = 0.0006         # drag deceleration = drag_k * v^2
    chute_ms: float = 6.5          # steady descent rate under the parachute
    chute_tau_s: float = 1.2       # how fast the chute reaches steady rate
    wind_east_ms: float = 4.0
    wind_north_ms: float = 1.0
    gps_regain_after_burn_s: float = 1.5
    apogee_phase_s: float = 2.0
    packets_after_landing: int = 6
    boot_offset_ms: int = 60_000   # tracker clock at the first packet


def _truth_states(prm: FlightParams) -> list[dict]:
    """Integrate the flight at 100 Hz and return one state per whole second."""
    dt = 0.01
    t = 0.0
    alt = vel = east = north = 0.0
    deployed = False
    landed = False
    t_apogee = None
    t_landed = None
    states: list[dict] = []
    step = 0
    while True:
        t = step * dt
        t_launch = prm.pad_wait_s
        if t >= t_launch and not landed:
            if t < t_launch + prm.burn_s:
                acc = prm.thrust_accel - G - prm.drag_k * vel * abs(vel)
                vel += acc * dt
            elif not deployed:
                acc = -G - prm.drag_k * vel * abs(vel)
                vel += acc * dt
                if vel <= 0:
                    deployed = True
                    t_apogee = t
            else:
                vel += (-prm.chute_ms - vel) * dt / prm.chute_tau_s
            alt += vel * dt
            if deployed:
                east += prm.wind_east_ms * dt
                north += prm.wind_north_ms * dt
            elif alt > 0:
                east += 0.25 * prm.wind_east_ms * dt
                north += 0.25 * prm.wind_north_ms * dt
            if deployed and alt <= 0:
                alt, vel, landed, t_landed = 0.0, 0.0, True, t
        if step % 100 == 0:
            states.append({"t": t, "alt": alt, "vel": vel, "east": east, "north": north,
                           "t_apogee": t_apogee, "t_landed": t_landed, "landed": landed})
            if landed and (t - t_landed) >= prm.packets_after_landing - 1 + 1e-9:
                break
        step += 1
        if step > 100 * 3600:
            raise RuntimeError("flight never landed; check parameters")
    return states


def generate_flight(prm: FlightParams | None = None) -> list[GroundFrame]:
    """Return one GroundFrame per second, from arming on the pad to a few
    seconds after landing."""
    prm = prm or FlightParams()
    rng = random.Random(prm.seed)
    states = _truth_states(prm)
    t_launch = prm.pad_wait_s
    t_gps_back = t_launch + prm.burn_s + prm.gps_regain_after_burn_s
    cos_lat = math.cos(math.radians(prm.pad_lat))

    frames: list[GroundFrame] = []
    last_lat_e7 = round(prm.pad_lat * 1e7)
    last_lon_e7 = round(prm.pad_lon * 1e7)

    for seq, s in enumerate(states):
        t = s["t"]
        # Flight phase
        if t < t_launch:
            phase = PHASE_PAD
        elif t < t_launch + prm.burn_s:
            phase = PHASE_BOOST
        elif s["t_apogee"] is None:
            phase = PHASE_COAST
        elif s["landed"]:
            phase = PHASE_LANDED
        elif t < s["t_apogee"] + prm.apogee_phase_s:
            phase = PHASE_APOGEE
        else:
            phase = PHASE_DESCENT

        # GPS: no fix from ignition until shortly after burnout
        gps_ok = not (t_launch <= t < t_gps_back)
        if gps_ok:
            lat = prm.pad_lat + s["north"] / M_PER_DEG_LAT
            lon = prm.pad_lon + s["east"] / (M_PER_DEG_LAT * cos_lat)
            last_lat_e7, last_lon_e7 = round(lat * 1e7), round(lon * 1e7)
            fix, sats = FIX_3D, (12 if phase == PHASE_PAD else 10)
        else:
            fix, sats = FIX_NONE, 0           # the last known position is repeated

        baro_cm = round((s["alt"] + rng.gauss(0, 0.3)) * 100)
        vspeed_cms = round((s["vel"] + rng.gauss(0, 0.2)) * 100)
        gps_alt_cm = round((prm.pad_msl_m + s["alt"] + rng.gauss(0, 1.0)) * 100)
        battery_mv = 4100 - int(0.6 * t) - (60 if phase == PHASE_BOOST else 0)

        packet = Packet(
            rocket_id=prm.rocket_id, seq=seq, time_ms=prm.boot_offset_ms + seq * 1000,
            lat_e7=last_lat_e7, lon_e7=last_lon_e7,
            gps_alt_cm=gps_alt_cm, baro_alt_cm=baro_cm, vspeed_cms=vspeed_cms,
            battery_mv=battery_mv, sats=sats, fix_type=fix, phase=phase,
            flags=FLAG_ARMED,
        )

        # Receiver signal strength falls off with distance from the pad
        dist = math.hypot(s["alt"], haversine_m(
            prm.pad_lat, prm.pad_lon, last_lat_e7 / 1e7, last_lon_e7 / 1e7))
        rssi = max(-120, min(-30, round(-60 - 12 * math.log10(1 + dist / 10))))
        snr = max(-20, min(12, round(10 - dist / 500)))
        frames.append(GroundFrame(packet=packet, rssi_dbm=rssi, snr_db=snr))
    return frames

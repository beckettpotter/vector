# Vector protocol, version 1

This file is the single source of truth for how Vector devices talk.
The Python reference (`tools/vector_packet.py`) implements it. The Dart app
and the C++ firmware must match it byte for byte. `vectors.json` and
`vectors.h` (generated) prove it. Do not change this file without asking Claude.

## The two layers

| Layer | Size | Where it travels |
| --- | --- | --- |
| Packet | 34 bytes | Rocket tracker to ground node, over LoRa radio |
| Ground frame | 36 bytes | Ground node to app, as one binary WebSocket message |

A ground frame is the 34-byte packet unchanged, followed by two signed bytes the
ground node measured when the packet arrived: `rssi_dbm` (int8) then `snr_db` (int8).

## Packet layout (34 bytes, little-endian, no padding)

| Offset | Size | Field | Type | Meaning |
| --- | --- | --- | --- | --- |
| 0 | 1 | version | uint8 | Protocol version. Always 1 for now. |
| 1 | 2 | rocket_id | uint16 | Unique per tracker. |
| 3 | 2 | seq | uint16 | Counts up by 1 per packet, wraps at 65535. |
| 5 | 4 | time_ms | uint32 | Milliseconds since the tracker booted. |
| 9 | 4 | lat_e7 | int32 | Latitude in degrees times 10^7. |
| 13 | 4 | lon_e7 | int32 | Longitude in degrees times 10^7. |
| 17 | 4 | gps_alt_cm | int32 | GPS altitude above sea level, centimeters. |
| 21 | 4 | baro_alt_cm | int32 | Barometric altitude above the pad reference (set when armed), centimeters. |
| 25 | 2 | vspeed_cms | int16 | Vertical speed, centimeters per second. Up is positive. |
| 27 | 2 | battery_mv | uint16 | Battery voltage in millivolts. |
| 29 | 1 | gps_status | uint8 | Low 6 bits: satellite count (0 to 63). High 2 bits: fix type. |
| 30 | 1 | phase | uint8 | Flight phase code (below). |
| 31 | 1 | flags | uint8 | Bit 0 armed. Bit 1 low battery. Other bits 0. |
| 32 | 2 | crc16 | uint16 | CRC of bytes 0 to 31. |

Fix type: 0 none, 1 2D, 2 3D, 3 reserved.
Phase codes: 0 pad, 1 boost, 2 coast, 3 apogee, 4 descent, 5 landed.

When the GPS has no fix, the tracker repeats the last known latitude and longitude
and sets fix type 0 and satellites 0. The app must not draw those repeated
positions as new track points.

## CRC

CRC-16/CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF, no bit reflection,
no final XOR. Computed over bytes 0 to 31 and stored little-endian at offset 32.
Check value: the CRC of the ASCII text `123456789` is `0x29B1`.

## Rules for receivers

Check in this order and reject at the first failure. Rejected packets are
counted but otherwise ignored; never crash on bad input.

1. `bad_length`: not exactly 34 bytes (36 for a ground frame).
2. `bad_crc`: the stored CRC does not match.
3. `bad_version`: version is not 1. Receivers must reject versions they do not know.
4. `bad_phase`: phase is above 5.

A WebSocket message that is not binary, or whose ground frame is rejected, is
counted and ignored.

## Link rules (apps and ground node)

- Lost packets: for consecutive packets from one rocket, lost = `((seq - previous_seq) mod 65536) - 1`.
- A new flight session starts when `rocket_id` changes, when `time_ms` goes backward
  (tracker rebooted), or when a `pad` packet arrives after a `landed` packet.
- Stale link: no valid frame for 5 seconds. Lost link: no valid frame for 30 seconds.
- The app shows "time since last packet" at all times, and shows a clear warning when stale.

## Default addresses

- Real ground node (proposed): `ws://192.168.4.1:81`
- Simulator: `ws://localhost:8765`

## Units and conversions

Convert at the edges only. Inside the app use meters, seconds, meters per second and degrees.

- degrees = lat_e7 / 10^7 (same for longitude)
- meters = cm / 100
- m/s = cms / 100
- volts = mv / 1000
- 1 meter = 3.28084 feet (for display only)

## Flight statistics

Computed from decoded packets only. Reference: `tools/flight_stats.py`.
Expected values for the sample flight: `expected_stats.json`. The app must match each within 0.1.

| Statistic | Definition |
| --- | --- |
| launch packet | The first packet with phase boost. |
| apogee_m | Largest `baro_alt_cm`, divided by 100. If tied, the first. |
| time_to_apogee_s | (time_ms of the apogee packet minus time_ms of the launch packet) / 1000. |
| max_vertical_speed_ms | Largest absolute `vspeed_cms`, divided by 100. |
| descent_rate_ms | Average of `-vspeed_cms` over all packets with phase descent, divided by 100. |
| flight_time_s | (time_ms of the first landed packet minus time_ms of the launch packet) / 1000. |
| landing_distance_m | Haversine distance (Earth radius 6371000 m) from the first packet with a 3D fix to the last 3D-fix packet with phase landed. |
| packet_count | Number of packets. |

Haversine: `a = sin²(Δφ/2) + cos φ1 · cos φ2 · sin²(Δλ/2)`, `d = 2R · asin(√a)`.

## Test data (generated, never edit by hand)

| File | What it is |
| --- | --- |
| `vectors.json` | Valid and invalid packets and ground frames, with the expected result of each. |
| `vectors.h` | The same vectors as a C header, for the firmware tests. |
| `sample_flight.hex` | A complete simulated flight, one ground frame (72 hex characters) per line. |
| `sample_flight.csv` | The same flight decoded. The app's CSV export must match this file exactly. |
| `expected_stats.json` | The flight statistics the app must reproduce. |

Regenerate with `python tools/generate_contract_data.py` (only when Claude has said the protocol changed).

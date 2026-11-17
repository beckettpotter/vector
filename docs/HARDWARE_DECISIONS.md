# Hardware decisions (task 11 Part B)

The tracker and ground-node firmware are **not written yet, on purpose**. Radio settings,
transmit power, pin wiring and battery handling must come from the club and be reviewed by a
club member, not from an AI. Take this page to the club, fill in the answers, then bring it back
to Claude.

Reminder: the tracker is passive telemetry. It must never be connected to ignition, ejection,
deployment or recovery electronics.

| Question | Answer | Who decided |
| --- | --- | --- |
| Reviewing club member (name, and how to reach them) | | |
| Tracker LoRa board (exact model, for example an SX1262 board with ESP32-S3 or RP2040) | | |
| Ground node LoRa board (exact model) | | |
| GPS module (exact model; does it support an airborne mode?) | | |
| Barometer (exact model, for example BMP390 or MS5611) | | |
| Battery (type, capacity, connector) and how it is charged (off the board, with a commercial charger?) | | |
| Radio frequency band (for example 915 MHz US ISM) and exact channel | | |
| LoRa settings: spreading factor, bandwidth, coding rate | | |
| Transmit power, and the FCC rule or licence it falls under | | |
| Does anyone hold an amateur radio licence (call sign)? Needed for higher power or 70 cm | | |
| Antennas (tracker and ground node), and where the tracker antenna sits in the airframe | | |
| Ground node Wi-Fi network name and password policy | | |
| Rocket IDs: how they are assigned to trackers | | |
| Parts budget | | |
| RSO sign-off before the first flight (name, date) | | |

## Already decided (from the kit)

- Packet format, CRC and ground frame: `protocol/PROTOCOL.md` (version 1, 34 bytes, one per second).
- Ground node serves frames over WebSocket on its own Wi-Fi; proposed address `ws://192.168.4.1:81`.
- Packet library (`firmware/lib/vector_packet/`) and phase detector (`firmware/lib/phase_detector/`)
  are written and tested without hardware. Phase thresholds are named constants at the top of
  `phase_detector.h` for the club to tune.

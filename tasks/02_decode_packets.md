# Task 02: Decode packets in the app

## Goal
Dart code that turns the 34-byte packet and the 36-byte ground frame into typed objects,
and rejects bad data exactly like the Python reference.

## Read first
`AGENTS.md`, `protocol/PROTOCOL.md` (the layout table and "Rules for receivers"),
`tools/vector_packet.py` (the reference), and the first 30 lines of `protocol/vectors.json`.

## Do
1. `app/lib/protocol/crc16.dart`: CRC-16/CCITT-FALSE. `crc16(Uint8List)` returns an int.
2. `app/lib/protocol/packet.dart`:
   - `class Packet` with final fields named like the spec but in Dart style (`rocketId`, `seq`, `timeMs`,
     `latE7`, `lonE7`, `gpsAltCm`, `baroAltCm`, `vspeedCms`, `batteryMv`, `sats`, `fixType`, `phase`, `flags`),
     plus getters `latDeg`, `lonDeg`, `baroAltM`, `vspeedMs`, `armed`, `lowBattery`, `has3dFix`.
   - `enum Phase { pad, boost, coast, apogee, descent, landed }`.
   - `class PacketError implements Exception` with a `code` string: `bad_length`, `bad_crc`, `bad_version`, `bad_phase`.
   - `Packet decodePacket(Uint8List data)` that checks in the order the spec says: length, CRC, version, phase.
   - `class GroundFrame { Packet packet; int rssiDbm; int snrDb; }` and `GroundFrame decodeGroundFrame(Uint8List data)`.
   Use `ByteData` with `Endian.little`. Signed fields must use the signed getters (`getInt32`, `getInt16`, `getInt8`).
3. `app/test/protocol_test.dart`: load `../protocol/vectors.json` (tests run from `app/`), and check
   - every entry in `valid`: decoded fields equal `fields`;
   - every entry in `invalid`: throws a `PacketError` with the listed `error` code;
   - every entry in `ground_valid` and `ground_invalid` the same way;
   - the CRC of the ASCII text `123456789` is `0x29B1`.

## Do not
- Edit anything in `protocol/`. Do not add packages (`dart:convert`, `dart:typed_data`, `dart:io` are enough).
- Add an encoder. The app only decodes.

## Done when
`python scripts/check.py` passes, and the test log shows every vector was checked (a loop over all of them, not a sample).

## Then
Tick task 02. Tell the person how many vectors the tests covered.

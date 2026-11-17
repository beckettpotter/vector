import 'dart:typed_data';

import 'crc16.dart';

/// Wire format: protocol/PROTOCOL.md. Reference: tools/vector_packet.py.
const int protocolVersion = 1;
const int packetSize = 34;
const int groundFrameSize = 36;

enum Phase { pad, boost, coast, apogee, descent, landed }

const int fixNone = 0;
const int fix2d = 1;
const int fix3d = 2;

class PacketError implements Exception {
  /// One of bad_length, bad_crc, bad_version, bad_phase.
  final String code;
  final String message;
  const PacketError(this.code, [this.message = '']);

  @override
  String toString() => message.isEmpty ? 'PacketError($code)' : 'PacketError($code: $message)';
}

class Packet {
  final int version;
  final int rocketId;
  final int seq;
  final int timeMs;
  final int latE7;
  final int lonE7;
  final int gpsAltCm;
  final int baroAltCm;
  final int vspeedCms;
  final int batteryMv;
  final int sats;
  final int fixType;
  final Phase phase;
  final int flags;

  const Packet({
    this.version = protocolVersion,
    required this.rocketId,
    required this.seq,
    required this.timeMs,
    required this.latE7,
    required this.lonE7,
    required this.gpsAltCm,
    required this.baroAltCm,
    required this.vspeedCms,
    required this.batteryMv,
    required this.sats,
    required this.fixType,
    required this.phase,
    required this.flags,
  });

  double get latDeg => latE7 / 1e7;
  double get lonDeg => lonE7 / 1e7;
  double get gpsAltM => gpsAltCm / 100.0;
  double get baroAltM => baroAltCm / 100.0;
  double get vspeedMs => vspeedCms / 100.0;
  double get batteryV => batteryMv / 1000.0;
  bool get armed => (flags & 0x01) != 0;
  bool get lowBattery => (flags & 0x02) != 0;
  bool get has3dFix => fixType >= fix3d;
}

class GroundFrame {
  final Packet packet;
  final int rssiDbm;
  final int snrDb;

  /// The 36 bytes as received, kept so recordings are byte-exact.
  final Uint8List? raw;
  const GroundFrame(this.packet, this.rssiDbm, this.snrDb, [this.raw]);
}

/// 34 bytes -> Packet. Checks in the spec's order: length, CRC, version, phase.
Packet decodePacket(Uint8List data) {
  if (data.length != packetSize) {
    throw PacketError('bad_length', 'expected $packetSize bytes, got ${data.length}');
  }
  final b = ByteData.sublistView(data);
  if (crc16(data, 32) != b.getUint16(32, Endian.little)) {
    throw const PacketError('bad_crc');
  }
  final version = b.getUint8(0);
  if (version != protocolVersion) throw PacketError('bad_version', 'got version $version');
  final phase = b.getUint8(30);
  if (phase > Phase.landed.index) throw PacketError('bad_phase', 'got phase $phase');
  final gpsStatus = b.getUint8(29);
  return Packet(
    version: version,
    rocketId: b.getUint16(1, Endian.little),
    seq: b.getUint16(3, Endian.little),
    timeMs: b.getUint32(5, Endian.little),
    latE7: b.getInt32(9, Endian.little),
    lonE7: b.getInt32(13, Endian.little),
    gpsAltCm: b.getInt32(17, Endian.little),
    baroAltCm: b.getInt32(21, Endian.little),
    vspeedCms: b.getInt16(25, Endian.little),
    batteryMv: b.getUint16(27, Endian.little),
    sats: gpsStatus & 0x3F,
    fixType: gpsStatus >> 6,
    phase: Phase.values[phase],
    flags: b.getUint8(31),
  );
}

/// 36 bytes -> GroundFrame (packet, then rssi int8, then snr int8).
GroundFrame decodeGroundFrame(Uint8List data) {
  if (data.length != groundFrameSize) {
    throw PacketError('bad_length', 'expected $groundFrameSize bytes, got ${data.length}');
  }
  final packet = decodePacket(Uint8List.sublistView(data, 0, packetSize));
  final b = ByteData.sublistView(data);
  return GroundFrame(packet, b.getInt8(34), b.getInt8(35), Uint8List.fromList(data));
}

Uint8List hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

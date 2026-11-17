import 'dart:io';
import 'dart:typed_data';

import 'package:vector/protocol/crc16.dart';
import 'package:vector/protocol/flight_file.dart';
import 'package:vector/protocol/packet.dart';

/// Test-only encoder (the app itself only decodes).
Uint8List encodeFrame(Packet p, {int rssi = -60, int snr = 10}) {
  final b = ByteData(groundFrameSize);
  b.setUint8(0, p.version);
  b.setUint16(1, p.rocketId, Endian.little);
  b.setUint16(3, p.seq, Endian.little);
  b.setUint32(5, p.timeMs, Endian.little);
  b.setInt32(9, p.latE7, Endian.little);
  b.setInt32(13, p.lonE7, Endian.little);
  b.setInt32(17, p.gpsAltCm, Endian.little);
  b.setInt32(21, p.baroAltCm, Endian.little);
  b.setInt16(25, p.vspeedCms, Endian.little);
  b.setUint16(27, p.batteryMv, Endian.little);
  b.setUint8(29, (p.fixType << 6) | p.sats);
  b.setUint8(30, p.phase.index);
  b.setUint8(31, p.flags);
  final bytes = b.buffer.asUint8List();
  b.setUint16(32, crc16(bytes, 32), Endian.little);
  b.setInt8(34, rssi);
  b.setInt8(35, snr);
  return bytes;
}

Packet makePacket({
  int rocketId = 1,
  int seq = 0,
  int timeMs = 1000,
  Phase phase = Phase.pad,
  int baroAltCm = 0,
  int vspeedCms = 0,
  int fixType = fix3d,
  int sats = 10,
  int flags = 1,
  int batteryMv = 4000,
  int latE7 = 329900000,
  int lonE7 = -1069750000,
}) =>
    Packet(
      rocketId: rocketId, seq: seq, timeMs: timeMs, latE7: latE7, lonE7: lonE7,
      gpsAltCm: 140000, baroAltCm: baroAltCm, vspeedCms: vspeedCms, batteryMv: batteryMv,
      sats: sats, fixType: fixType, phase: phase, flags: flags,
    );

GroundFrame makeFrame({int rssi = -60, int snr = 10, int rocketId = 1, int seq = 0, int timeMs = 1000,
        Phase phase = Phase.pad, int baroAltCm = 0, int vspeedCms = 0, int fixType = fix3d, int sats = 10,
        int flags = 1, int batteryMv = 4000}) =>
    decodeGroundFrame(encodeFrame(
        makePacket(rocketId: rocketId, seq: seq, timeMs: timeMs, phase: phase, baroAltCm: baroAltCm,
            vspeedCms: vspeedCms, fixType: fixType, sats: sats, flags: flags, batteryMv: batteryMv),
        rssi: rssi, snr: snr));

List<GroundFrame> sampleFlight() => parseHexFlight(File('../protocol/sample_flight.hex').readAsStringSync());

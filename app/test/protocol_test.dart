import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/protocol/crc16.dart';
import 'package:vector/protocol/packet.dart';

void main() {
  final vectors = jsonDecode(File('../protocol/vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final valid = (vectors['valid'] as List).cast<Map<String, dynamic>>();

  void expectFields(Packet p, Map<String, dynamic> f, String name) {
    final actual = {
      'version': p.version, 'rocket_id': p.rocketId, 'seq': p.seq, 'time_ms': p.timeMs,
      'lat_e7': p.latE7, 'lon_e7': p.lonE7, 'gps_alt_cm': p.gpsAltCm, 'baro_alt_cm': p.baroAltCm,
      'vspeed_cms': p.vspeedCms, 'battery_mv': p.batteryMv, 'sats': p.sats, 'fix_type': p.fixType,
      'phase': p.phase.index, 'flags': p.flags,
    };
    expect(actual, equals(f), reason: name);
  }

  test('CRC of "123456789" is 0x29B1', () {
    expect(crc16(Uint8List.fromList(ascii.encode('123456789'))), 0x29B1);
    expect(vectors['crc_check']['crc16_ccitt_false'], '0x29B1');
  });

  test('every valid packet vector decodes to its fields', () {
    for (final v in valid) {
      expectFields(decodePacket(hexToBytes(v['hex'])), v['fields'], v['name']);
    }
    expect(valid.length, 8);
  });

  test('every invalid packet vector is rejected with its code', () {
    final invalid = (vectors['invalid'] as List).cast<Map<String, dynamic>>();
    for (final v in invalid) {
      expect(() => decodePacket(hexToBytes(v['hex'])),
          throwsA(isA<PacketError>().having((e) => e.code, 'code', v['error'])),
          reason: v['name']);
    }
    expect(invalid.length, 7);
  });

  test('every valid ground frame vector decodes', () {
    final byName = {for (final v in valid) v['name']: v['fields']};
    final ground = (vectors['ground_valid'] as List).cast<Map<String, dynamic>>();
    for (final g in ground) {
      final frame = decodeGroundFrame(hexToBytes(g['hex']));
      expectFields(frame.packet, byName[g['packet']], g['name']);
      expect(frame.rssiDbm, g['rssi_dbm'], reason: g['name']);
      expect(frame.snrDb, g['snr_db'], reason: g['name']);
    }
    expect(ground.length, 3);
  });

  test('every invalid ground frame vector is rejected with its code', () {
    final ground = (vectors['ground_invalid'] as List).cast<Map<String, dynamic>>();
    for (final g in ground) {
      expect(() => decodeGroundFrame(hexToBytes(g['hex'])),
          throwsA(isA<PacketError>().having((e) => e.code, 'code', g['error'])),
          reason: g['name']);
    }
    expect(ground.length, 2);
  });

  test('derived values use signed fields and the right units', () {
    final neg = valid.firstWhere((v) => v['name'] == 'negative_values');
    final p = decodePacket(hexToBytes(neg['hex']));
    expect(p.latDeg, closeTo(-33.8688, 1e-9));
    expect(p.baroAltM, -1.5);
    expect(p.vspeedMs, -20.0);
    expect(p.lowBattery, isTrue);
    expect(p.armed, isFalse);
    expect(p.has3dFix, isFalse);
  });
}

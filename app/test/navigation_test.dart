import 'package:flutter_test/flutter_test.dart';
import 'package:vector/protocol/navigation.dart';
import 'package:vector/protocol/packet.dart';

import 'helpers.dart';

void main() {
  test('bearings for the four directions', () {
    expect(bearingDeg(0, 0, 1, 0), closeTo(0, 1e-9));
    expect(bearingDeg(0, 0, 0, 1), closeTo(90, 1e-9));
    expect(bearingDeg(0, 0, -1, 0), closeTo(180, 1e-9));
    expect(bearingDeg(0, 0, 0, -1), closeTo(270, 1e-9));
  });

  test('(0,0) to (0,1) is about 111195 m at bearing 90', () {
    expect(haversineM(0, 0, 0, 1), closeTo(111195, 1));
    expect(bearingDeg(0, 0, 0, 1), closeTo(90, 1e-9));
  });

  test('cardinals, including the edges', () {
    expect(cardinal(0), 'N');
    expect(cardinal(22.4), 'N');
    expect(cardinal(22.6), 'NE');
    expect(cardinal(90), 'E');
    expect(cardinal(180), 'S');
    expect(cardinal(270), 'W');
    expect(cardinal(337.4), 'NW');
    expect(cardinal(337.6), 'N');
    expect(cardinal(359.9), 'N');
  });

  test('16-point cardinals', () {
    expect(cardinal16(0), 'N');
    expect(cardinal16(11.2), 'N');
    expect(cardinal16(11.3), 'NNE');
    expect(cardinal16(67.5), 'ENE');
    expect(cardinal16(348.8), 'N');
  });

  test('last known fix skips packets without a fix and reports the age', () {
    final packets = [
      makePacket(seq: 0, timeMs: 1000),
      makePacket(seq: 1, timeMs: 2000),
      makePacket(seq: 2, timeMs: 3000, fixType: fixNone),
      makePacket(seq: 3, timeMs: 4000, fixType: fixNone),
    ];
    final fix = lastKnownFix(packets)!;
    expect(fix.packet.seq, 1);
    expect(fix.ageMs, 2000);
    expect(lastKnownFix([makePacket(fixType: fixNone)]), isNull);
  });

  test('sample flight: landing is about 620 m at about 76 degrees (ENE) from the pad', () {
    final packets = sampleFlight().map((f) => f.packet).toList();
    final fix = lastKnownFix(packets)!.packet;
    final pad = packets.first;
    expect(haversineM(pad.latDeg, pad.lonDeg, fix.latDeg, fix.lonDeg), closeTo(619.7, 0.5));
    final b = bearingDeg(pad.latDeg, pad.lonDeg, fix.latDeg, fix.lonDeg);
    expect(b, closeTo(76, 1.5));
    expect(cardinal(b), 'E'); // 8-point sector
    expect(cardinal16(b), 'ENE');
  });
}

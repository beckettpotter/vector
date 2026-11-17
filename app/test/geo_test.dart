import 'package:flutter_test/flutter_test.dart';
import 'package:vector/protocol/geo.dart';
import 'package:vector/protocol/packet.dart';

import 'helpers.dart';

void main() {
  test('0.001 degrees of latitude is about 111.2 m north', () {
    final p = toEastNorth(32.99, -106.975, 32.991, -106.975);
    expect(p.northM, closeTo(111.2, 0.1));
    expect(p.eastM, closeTo(0, 1e-9));
  });

  test('longitude shrinks by the cosine of latitude', () {
    final atEquator = toEastNorth(0, 0, 0, 0.001);
    final at60 = toEastNorth(60, 0, 60, 0.001);
    expect(atEquator.eastM, closeTo(111.2, 0.1));
    expect(at60.eastM, closeTo(atEquator.eastM * 0.5, 0.01));
    expect(toEastNorth(10, 10, 10, 9.999).eastM, lessThan(0));
  });

  test('ring choice grows with distance', () {
    expect(chooseRings(50), [100]);
    expect(chooseRings(100), [100]);
    expect(chooseRings(620), [100, 250, 500, 1000]);
    expect(chooseRings(1500), [100, 250, 500, 1000, 2000]);
    expect(ringLabel(250), '250 m');
    expect(ringLabel(2000), '2 km');
  });

  test('sample flight: gap packets are not path points, and the gap is marked', () {
    final packets = sampleFlight().map((f) => f.packet).toList();
    final track = buildTrack(packets);
    final fixCount = packets.where((p) => p.has3dFix).length;
    expect(track.points.length, fixCount);
    expect(fixCount, lessThan(packets.length));
    expect(track.points.where((p) => p.gapBefore).length, 1);
    expect(track.pad, packets.first);
    final last = track.latestPos!;
    expect(last.distanceM, closeTo(619.7, 2));
    expect(last.eastM, greaterThan(0));
    expect(last.northM, greaterThan(0));
  });

  test('no fix at all gives an empty track', () {
    final track = buildTrack([makePacket(fixType: fixNone)]);
    expect(track.pad, isNull);
    expect(track.points, isEmpty);
  });
}

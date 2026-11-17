import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/openrocket/compare.dart';
import 'package:vector/openrocket/projection.dart';
import 'package:vector/protocol/packet.dart';

import 'helpers.dart';

Projection real() =>
    parseOpenRocketCsv(File('test/fixtures/openrocket_real.csv').readAsBytesSync(), name: 'openrocket_real');

void main() {
  test("Beckett's real OpenRocket export gives the plan's numbers", () {
    final p = real();
    expect(p.t.length, 399);
    expect(p.apogeeM, closeTo(852.6, 0.05));
    expect(p.apogeeM * 3.28084, closeTo(2797, 1));
    expect(p.apogeeT, closeTo(10.841, 1e-6));
    expect(p.burnoutT, closeTo(2.398, 1e-6));
    expect(p.burnoutAltM, closeTo(348.9, 0.5));
    expect(p.burnoutVvelMs, closeTo(187.5, 0.5));
    expect(p.maxVerticalSpeedMs, closeTo(211.2, 0.05));
    expect(p.maxTotalSpeedMs, closeTo(211.2, 0.05));
    expect(p.maxAccelG, closeTo(16.8, 0.05));
    expect(p.maxMach, closeTo(0.62, 0.005));
    expect(p.descentRateMs, closeTo(12.5, 0.1));
    expect(p.groundHitT, closeTo(80.078, 1e-6));
    expect(p.driftM, closeTo(160.7, 0.05));
    expect(p.driftDirDeg, closeTo(270, 0.5));
    expect(p.stabilityRodExitCal, closeTo(-0.41, 0.01));
    expect(p.stabilityMinCal, closeTo(-10.5, 0.05));
    expect(p.noRecoveryDevice, isTrue);
    expect(p.marginalStability, isTrue);
    expect(p.warnings, ['No recovery device defined in the simulation.']);
    expect(p.events.map((e) => e.name), [
      'SIM_WARN', 'IGNITION', 'LAUNCH', 'LIFTOFF', 'LAUNCHROD', 'BURNOUT', 'TUMBLE', 'APOGEE',
      'EJECTION_CHARGE', 'GROUND_HIT', 'SIMULATION_END',
    ]);
    expect(p.events.firstWhere((e) => e.name == 'LIFTOFF').t, 0.031);
  });

  Projection parse(String text, {List<int>? bytes}) => parseOpenRocketCsv(bytes ?? utf8.encode(text), name: 'x');

  const small = '# Simulation 1\n'
      '# Time (s),Altitude (m),Vertical velocity (m/s)\n'
      '# Event LAUNCH occurred at t=0 seconds\n'
      '0,0,NaN\n'
      '1,50,100\n'
      '# Event BURNOUT occurred at t=1.5 seconds\n'
      '2,150,1.0e2\n'
      '3,200,0\n'
      '# Event APOGEE occurred at t=3 seconds\n'
      '13,100,-10\n'
      '23,0,-10\n'
      '# Event GROUND_HIT occurred at t=23 seconds\n';

  test('comment header, events between rows, NaN, scientific notation, never a fixed step', () {
    final p = parse(small);
    expect(p.t, [0, 1, 2, 3, 13, 23]);
    expect(p.vvel.first.isNaN, isTrue); // NaN is missing, not zero
    expect(p.vvel[2], 100);
    expect(p.burnoutT, 1.5);
    expect(p.burnoutAltM, 100); // interpolated by time
    expect(p.altAt(8), 150);
    expect(p.altAt(-1), 0);
    expect(p.altAt(99), 0);
    expect(p.apogeeM, 200);
    expect(p.groundHitT, 23);
    expect(p.descentRateMs, closeTo(10, 1e-9));
    expect(p.driftM, isNull); // optional columns missing: those statistics are hidden
    expect(p.maxAccelG, isNull);
    expect(p.stabilityRodExitCal, isNull);
    expect(p.noRecoveryDevice, isFalse);
  });

  test('semicolon, tab and space separators, plain header, byte-order mark', () {
    for (final sep in [';', '\t']) {
      expect(parse(small.replaceAll(',', sep)).apogeeM, 200, reason: 'separator "$sep"');
    }
    final spaced = small.replaceAll(',', ' ');
    expect(parse(spaced).apogeeM, 200);
    expect(parse(spaced).vvel[1], 100);
    final plain = small.replaceFirst('# Time (s)', 'Time (s)');
    expect(parse(plain).apogeeM, 200);
    final bom = [0xEF, 0xBB, 0xBF, ...utf8.encode(small)];
    expect(parse('', bytes: bom).apogeeM, 200);
  });

  test('columns are matched by name: unicode units, zero-width space, case and spacing', () {
    final p = parse('#  time (s)\tALTITUDE  (m)\tStability margin calibers (​)\tVertical acceleration (m/s²)\n'
        '# Event LAUNCHROD occurred at t=0.5 seconds\n'
        '0\t0\tNaN\t0\n1\t10\t1.5\t98.0665\n2\t5\t2\t0\n');
    expect(p.apogeeM, 10);
    expect(p.stabilityRodExitCal, 1.5); // first value at or after the rod exit
    expect(p.maxAccelG, closeTo(10, 1e-9));
  });

  test('missing Time or Altitude: plain words naming the column to tick', () {
    expect(() => parse('# Altitude (m),Vertical velocity (m/s)\n0,0\n'),
        throwsA(isA<OpenRocketFormatException>().having((e) => e.message, 'message', contains("'Time'"))));
    expect(() => parse('# Time (s),Vertical velocity (m/s)\n0,0\n'),
        throwsA(isA<OpenRocketFormatException>().having((e) => e.message, 'message', contains("tick 'Altitude'"))));
    expect(() => parse('# Time (s),Altitude (m)\n'), throwsA(isA<OpenRocketFormatException>()));
  });

  test('times out of order are sorted, repeats dropped', () {
    final p = parse('# Time (s),Altitude (m)\n2,20\n0,0\n1,10\n1,11\n3,5\n');
    expect(p.t, [0, 1, 2, 3]);
    expect(p.alt, [0, 10, 20, 5]);
  });

  test('warnings block and SIM_WARN are surfaced once; no recovery device is detected', () {
    final p = parse('# Simulation warnings:\n#   No recovery device defined in the simulation.\n#   Too fast\n#\n'
        '# Time (s),Altitude (m)\n'
        '# Event SIM_WARN occurred at t=0 seconds: No recovery device defined in the simulation.\n'
        '0,0\n1,10\n2,0\n');
    expect(p.warnings, ['No recovery device defined in the simulation.', 'Too fast']);
    expect(p.noRecoveryDevice, isTrue);
  });

  test('saving into a flight file and reading back keeps the numbers', () {
    final p = real();
    final back = Projection.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.apogeeM, p.apogeeM);
    expect(back.t.length, 399);
    expect(back.vvel.first.isNaN, p.vvel.first.isNaN);
    expect(back.altAt(10), closeTo(p.altAt(10), 0.01));
    expect(back.noRecoveryDevice, isTrue);
    expect(back.stabilityRodExitCal, p.stabilityRodExitCal);
  });

  group('real versus predicted, from the sample flight', () {
    final packets = [for (final f in sampleFlight()) f.packet];
    final launch = launchTimeMs(packets)!;
    final apogeeMs = packets.reduce((a, b) => b.baroAltCm > a.baroAltCm ? b : a).timeMs;

    /// An OpenRocket-style file made from the real flight itself.
    Projection synthetic({double altScale = 1, double slowerDescentMs = 0}) {
      final b = StringBuffer('# Time (s),Altitude (m),Vertical velocity (m/s)\n');
      var landed = false;
      for (final p in packets) {
        if (p.timeMs < launch) continue;
        final t = (p.timeMs - launch) / 1000.0;
        var alt = p.baroAltM * altScale, v = p.vspeedMs * altScale;
        if (p.timeMs > apogeeMs) {
          alt += slowerDescentMs * (p.timeMs - apogeeMs) / 1000.0;
          v += slowerDescentMs;
        }
        if (p.phase == Phase.landed && !landed) {
          b.writeln('# Event GROUND_HIT occurred at t=$t seconds');
          landed = true;
        }
        b.writeln('$t,$alt,$v');
      }
      return parse(b.toString());
    }

    test('an exact prediction compares as zero error', () {
      final c = compareFlight(synthetic(), packets)!;
      expect(c.rows[0].difference, closeTo(0, 1e-6));
      expect(c.rows[1].difference, closeTo(0, 1e-6));
      expect(c.rmsAltM, closeTo(0, 1e-6));
      expect(c.summary.first, startsWith('Apogee matched the prediction'));
    });

    test('prediction 5% high: flew 4.8% lower; prediction falls 1 m/s slower: came down 1 m/s faster', () {
      final base = compareFlight(synthetic(), packets)!;
      final high = compareFlight(synthetic(altScale: 1.05), packets)!;
      expect(high.rows[0].predicted, closeTo(packets.map((p) => p.baroAltM).reduce((a, b) => a > b ? a : b) * 1.05, 1e-6));
      expect(high.rows[0].percent, closeTo(100 * (1 / 1.05 - 1), 0.01));
      expect(high.summary.first, startsWith('Flew 4.8% lower than predicted'));
      expect(high.rmsAltM, greaterThan(0));
      expect(high.phases.firstWhere((e) => e.phase == 'Coast').meanM, lessThan(0));

      final slow = compareFlight(synthetic(slowerDescentMs: 1), packets)!;
      final shift = slow.rows[3].predicted - base.rows[3].predicted;
      expect(shift, closeTo(-1, 0.01)); // the prediction falls 1 m/s slower
      expect(slow.rows[3].difference - base.rows[3].difference, closeTo(1, 0.01));
      expect(slow.rows[0].difference, closeTo(0, 1e-6)); // apogee unchanged
      expect(slow.phases.firstWhere((e) => e.phase == 'Descent').meanM, lessThan(0));
    });

    test('live: predicted altitude at the packet time, difference and above/below', () {
      final proj = synthetic(altScale: 1.05);
      final upTo = packets.where((p) => p.timeMs <= apogeeMs).toList();
      final live = liveComparison(proj, upTo)!;
      expect(live.tS, (apogeeMs - launch) / 1000.0);
      expect(live.altDiffM, closeTo(upTo.last.baroAltM - upTo.last.baroAltM * 1.05, 1e-6));
      expect(live.below, isTrue);
      expect(liveComparison(proj, packets.where((p) => p.phase == Phase.pad).toList()), isNull); // before launch
      final nudged = liveComparison(proj, upTo, offsetS: 1)!;
      expect(nudged.tS, live.tS + 1);
    });

    test('no recovery device: descent and landing are labelled, not compared', () {
      final c = compareFlight(real(), packets)!;
      for (final r in c.rows.sublist(3)) {
        expect(r.excluded, noRecoveryLabel);
        expect(r.comparable, isFalse);
      }
      expect(c.rows[0].comparable, isTrue);
      expect(c.summary.last, contains('no recovery device'));
    });
  });
}

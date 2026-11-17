import 'package:flutter_test/flutter_test.dart';
import 'package:vector/link/link_monitor.dart';
import 'package:vector/protocol/packet.dart';

import 'helpers.dart';

void main() {
  late int now;
  late LinkMonitor m;
  setUp(() {
    now = 0;
    m = LinkMonitor(nowMs: () => now);
  });

  test('waiting until the first frame', () {
    expect(m.status, LinkStatus.waiting);
    expect(m.sinceLastMs, isNull);
    expect(m.latest, isNull);
  });

  test('live, then stale at 5 s, then lost at 30 s', () {
    m.onFrame(makeFrame());
    expect(m.status, LinkStatus.live);
    now = 4999;
    expect(m.status, LinkStatus.live);
    expect(m.sinceLastMs, 4999);
    now = 5000;
    expect(m.status, LinkStatus.stale);
    now = 29999;
    expect(m.status, LinkStatus.stale);
    now = 30000;
    expect(m.status, LinkStatus.lost);
    m.onFrame(makeFrame(seq: 1, timeMs: 2000));
    expect(m.status, LinkStatus.live);
  });

  test('counts frames and rejects', () {
    m.onFrame(makeFrame());
    m.onRejected();
    m.onRejected();
    expect(m.frameCount, 1);
    expect(m.rejectedCount, 2);
  });

  test('lost packets from sequence gaps', () {
    m.onFrame(makeFrame(seq: 10, timeMs: 1000));
    m.onFrame(makeFrame(seq: 11, timeMs: 2000));
    expect(m.lostCount, 0);
    m.onFrame(makeFrame(seq: 14, timeMs: 5000));
    expect(m.lostCount, 2);
  });

  test('sequence wraps from 65535 to 0 without counting a loss', () {
    m.onFrame(makeFrame(seq: 65534, timeMs: 1000));
    m.onFrame(makeFrame(seq: 65535, timeMs: 2000));
    m.onFrame(makeFrame(seq: 0, timeMs: 3000));
    expect(m.lostCount, 0);
    m.onFrame(makeFrame(seq: 2, timeMs: 5000));
    expect(m.lostCount, 1);
  });

  test('a gap across the wrap is counted', () {
    m.onFrame(makeFrame(seq: 65534, timeMs: 1000));
    m.onFrame(makeFrame(seq: 1, timeMs: 4000));
    expect(m.lostCount, 2);
  });

  test('a duplicate frame is not a loss', () {
    m.onFrame(makeFrame(seq: 5, timeMs: 1000));
    m.onFrame(makeFrame(seq: 5, timeMs: 1000));
    expect(m.lostCount, 0);
  });

  test('first frame starts a session; normal frames do not', () {
    expect(m.onFrame(makeFrame(seq: 0)), isTrue);
    expect(m.onFrame(makeFrame(seq: 1, timeMs: 2000, phase: Phase.boost)), isFalse);
    expect(m.session, 1);
  });

  test('new session when the rocket id changes', () {
    m.onFrame(makeFrame(rocketId: 1));
    expect(m.onFrame(makeFrame(rocketId: 2, seq: 1, timeMs: 2000)), isTrue);
    expect(m.session, 2);
  });

  test('new session when time goes backward (tracker reboot), and no false loss', () {
    m.onFrame(makeFrame(seq: 500, timeMs: 90000));
    expect(m.onFrame(makeFrame(seq: 0, timeMs: 1000)), isTrue);
    expect(m.lostCount, 0);
  });

  test('new session when a pad packet follows a landed packet', () {
    m.onFrame(makeFrame(seq: 0, timeMs: 1000, phase: Phase.landed));
    expect(m.onFrame(makeFrame(seq: 1, timeMs: 2000, phase: Phase.landed)), isFalse);
    expect(m.onFrame(makeFrame(seq: 2, timeMs: 3000, phase: Phase.pad)), isTrue);
  });

  test('the sample flight is one session with no losses', () {
    var sessions = 0;
    for (final f in sampleFlight()) {
      if (m.onFrame(f)) sessions++;
    }
    expect(sessions, 1);
    expect(m.frameCount, 178);
    expect(m.lostCount, 0);
  });
}

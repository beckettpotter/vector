import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/link/frame_source.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/link/replay_link.dart';
import 'package:vector/protocol/packet.dart';
import 'package:vector/storage/flight_store.dart';
import 'package:vector/storage/recorder.dart';

import 'helpers.dart';

Future<void> waitFor(bool Function() done) => Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 10));
      return !done();
    }).timeout(const Duration(seconds: 10));

void main() {
  test('replays the sample flight through the normal link, and it is not recorded again', () async {
    final tmp = Directory.systemTemp.createTempSync('vector_replay_');
    final store = FlightStore(Directory('${tmp.path}/flights'));
    final link = LinkController(nowMs: () => 0, tick: false);
    final rec = Recorder(store: store, link: link);
    final replay = ReplayLink(sampleFlight(), name: 'Sample', speed: 1000);
    await link.useSource(replay);
    await waitFor(() => replay.state == LinkConnection.finished);
    await Future.delayed(const Duration(milliseconds: 20));
    expect(link.monitor.frameCount, 178);
    expect(link.monitor.latest!.packet.phase, Phase.landed);
    expect(link.maxAltM, 948.53);
    expect(link.sessionFrames.length, 178);
    await rec.flush();
    expect(await store.list(), isEmpty);
    rec.dispose();
    link.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('pause, seek forward and back', () async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final replay = ReplayLink(sampleFlight(), name: 'Sample', speed: 1000);
    await link.useSource(replay);
    replay.pause();
    replay.seek(100);
    await Future.delayed(const Duration(milliseconds: 20));
    expect(link.sessionFrames.last.packet.seq, 99);
    replay.seek(20); // backwards: starts a new session from the beginning
    await Future.delayed(const Duration(milliseconds: 20));
    expect(link.sessionFrames.length, 20);
    expect(link.sessionFrames.last.packet.seq, 19);
    final before = link.monitor.frameCount;
    await Future.delayed(const Duration(milliseconds: 50));
    expect(link.monitor.frameCount, before, reason: 'paused');
    link.dispose();
  });
}

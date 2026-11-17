import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/link/frame_source.dart';
import 'package:vector/link/ws_link.dart';
import 'package:vector/protocol/packet.dart';

import 'helpers.dart';

// Uses a real local WebSocket server (plain test(), so no widget binding blocks networking).
void main() {
  test('decodes frames, counts text and bad frames, never crashes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      ws.add(encodeFrame(makePacket(seq: 1)));
      ws.add('hello');                                 // text: rejected
      ws.add(Uint8List(10));                           // wrong length
      final bad = encodeFrame(makePacket(seq: 2));
      bad[10] ^= 0xFF;                                 // corrupted
      ws.add(bad);
      ws.add(encodeFrame(makePacket(seq: 3)));
    });
    final link = WsLink(Uri.parse('ws://127.0.0.1:${server.port}'));
    final frames = <GroundFrame>[];
    final rejects = <String>[];
    link.frames.listen(frames.add);
    link.rejects.listen(rejects.add);
    await link.start();
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 20));
      return frames.length < 2;
    }).timeout(const Duration(seconds: 5));
    expect(frames.map((f) => f.packet.seq), [1, 3]);
    expect(rejects, ['not_binary', 'bad_length', 'bad_crc']);
    expect(link.state, LinkConnection.connected);
    await link.dispose();
    await server.close(force: true);
  });

  test('retries with back-off when nothing is listening, and stop() ends it', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final link = WsLink(Uri.parse('ws://127.0.0.1:$port'),
        backoff: const [Duration(milliseconds: 10), Duration(milliseconds: 20)]);
    final states = <LinkConnection>[];
    link.states.listen(states.add);
    await link.start();
    await Future.delayed(const Duration(milliseconds: 300));
    expect(states.where((s) => s == LinkConnection.retrying).length, greaterThanOrEqualTo(2));
    expect(link.lastError, isNotNull);
    await link.stop();
    expect(link.state, LinkConnection.disconnected);
    await Future.delayed(const Duration(milliseconds: 50)); // let queued events arrive
    final count = states.length;
    await Future.delayed(const Duration(milliseconds: 100));
    expect(states.length, count, reason: 'no reconnect attempts after stop()');
    await link.dispose();
  });
}

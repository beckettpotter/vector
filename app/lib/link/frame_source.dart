import 'dart:async';

import '../protocol/packet.dart';

enum LinkConnection { disconnected, connecting, connected, retrying, finished }

/// Anything that produces ground frames: the WebSocket link or a replay.
abstract class FrameSource {
  Stream<GroundFrame> get frames;

  /// One event per rejected message (the error code, or 'not_binary').
  Stream<String> get rejects;
  Stream<LinkConnection> get states;
  LinkConnection get state;
  String? get lastError;

  /// True for a replay of a saved flight (not recorded again, shown as REPLAY).
  bool get isReplay => false;
  Future<void> start();
  Future<void> stop();
}

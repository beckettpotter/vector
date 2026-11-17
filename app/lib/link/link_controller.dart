import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/packet.dart';
import 'frame_source.dart';
import 'link_monitor.dart';
import 'ws_link.dart';

const String simulatorAddress = 'ws://localhost:8765';
const String groundNodeAddress = 'ws://192.168.4.1:81';

/// Glue between a FrameSource (live link or replay) and the screens. Holds the
/// link monitor and the frames of the current flight session.
class LinkController extends ChangeNotifier {
  final int Function() nowMs;
  late final LinkMonitor monitor;
  Timer? _ticker;

  LinkController({int Function()? nowMs, bool tick = true})
      : nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch) {
    monitor = LinkMonitor(nowMs: this.nowMs);
    // Re-draw regularly so "time since last packet" and STALE/LOST stay current.
    if (tick) _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => notifyListeners());
  }

  String address = simulatorAddress;
  FrameSource? _source;
  FrameSource? get source => _source;
  final List<StreamSubscription> _subs = [];

  /// Frames of the current session, oldest first.
  final List<GroundFrame> sessionFrames = [];
  double maxAltM = 0;

  /// Called with each valid frame, after the session state is updated.
  final List<void Function(GroundFrame frame, bool newSession)> frameListeners = [];

  LinkConnection get connection => _source?.state ?? LinkConnection.disconnected;
  String? get lastError => _source?.lastError;
  bool get isActive => _source != null && connection != LinkConnection.disconnected;

  Future<void> connect([String? newAddress]) async {
    if (newAddress != null) address = newAddress.trim();
    final uri = Uri.tryParse(address);
    if (uri == null || !(uri.scheme == 'ws' || uri.scheme == 'wss') || uri.host.isEmpty) {
      throw const FormatException('The address must look like ws://192.168.4.1:81');
    }
    await useSource(WsLink(uri));
  }

  /// The STALE/LOST warning was dismissed for the outage that followed the
  /// frame received at this clock time. The next frame changes that time, so
  /// a later outage shows the warning again.
  int? _dismissedAfterFrameAt;
  bool get warningDismissed =>
      _dismissedAfterFrameAt != null && _dismissedAfterFrameAt == monitor.lastFrameAtMs;
  void dismissWarning() {
    _dismissedAfterFrameAt = monitor.lastFrameAtMs;
    notifyListeners();
  }

  /// Start reading from any source (used by connect() and by replay).
  Future<void> useSource(FrameSource source) async {
    await disconnect();
    monitor.reset();
    _dismissedAfterFrameAt = null;
    sessionFrames.clear();
    maxAltM = 0;
    _source = source;
    _subs.add(source.frames.listen(handleFrame));
    _subs.add(source.rejects.listen((_) {
      monitor.onRejected();
      notifyListeners();
    }));
    _subs.add(source.states.listen((_) => notifyListeners()));
    notifyListeners();
    await source.start();
  }

  void handleFrame(GroundFrame frame) {
    final newSession = monitor.onFrame(frame);
    if (newSession) {
      sessionFrames.clear();
      maxAltM = 0;
    }
    sessionFrames.add(frame);
    if (frame.packet.baroAltM > maxAltM) maxAltM = frame.packet.baroAltM;
    for (final l in List.of(frameListeners)) {
      l(frame, newSession);
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final old = _source;
    _source = null;
    if (old != null) await old.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final old = _source;
    _source = null;
    for (final s in _subs) {
      s.cancel();
    }
    old?.stop();
    super.dispose();
  }
}

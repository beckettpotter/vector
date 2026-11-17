import '../protocol/packet.dart';

/// Link-health rules from protocol/PROTOCOL.md "Link rules". Pure logic: no
/// network and no Flutter, and the clock is injected so tests control time.
enum LinkStatus { waiting, live, stale, lost }

const int staleAfterMs = 5000;
const int lostAfterMs = 30000;

class LinkMonitor {
  final int Function() nowMs;
  LinkMonitor({required this.nowMs});

  GroundFrame? latest;
  int? _lastFrameAtMs;
  int frameCount = 0;
  int rejectedCount = 0;
  int lostCount = 0;

  /// Goes up by one each time a new flight session starts (0 = none yet).
  int session = 0;
  final Map<int, int> _lastSeqByRocket = {};

  /// Feed a valid frame. Returns true if it started a new session.
  bool onFrame(GroundFrame frame) {
    final p = frame.packet;
    final prev = latest?.packet;
    final rebooted = prev != null && p.rocketId == prev.rocketId && p.timeMs < prev.timeMs;
    final newSession = prev == null ||
        p.rocketId != prev.rocketId ||
        rebooted ||
        (p.phase == Phase.pad && prev.phase == Phase.landed);

    final prevSeq = _lastSeqByRocket[p.rocketId];
    // After a reboot the counter restarts, so a gap there is not packet loss.
    if (prevSeq != null && !rebooted) {
      final lost = ((p.seq - prevSeq) % 65536) - 1;
      if (lost > 0) lostCount += lost; // -1 means a duplicate; ignore it
    }
    _lastSeqByRocket[p.rocketId] = p.seq;

    latest = frame;
    _lastFrameAtMs = nowMs();
    frameCount++;
    if (newSession) session++;
    return newSession;
  }

  void onRejected() => rejectedCount++;

  /// Clock time of the last valid frame, or null if none yet.
  int? get lastFrameAtMs => _lastFrameAtMs;

  /// Milliseconds since the last valid frame, or null if none yet.
  int? get sinceLastMs => _lastFrameAtMs == null ? null : nowMs() - _lastFrameAtMs!;

  LinkStatus get status {
    final since = sinceLastMs;
    if (since == null) return LinkStatus.waiting;
    if (since >= lostAfterMs) return LinkStatus.lost;
    if (since >= staleAfterMs) return LinkStatus.stale;
    return LinkStatus.live;
  }

  void reset() {
    latest = null;
    _lastFrameAtMs = null;
    frameCount = rejectedCount = lostCount = session = 0;
    _lastSeqByRocket.clear();
  }
}

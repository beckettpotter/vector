import '../link/frame_source.dart';
import '../link/link_monitor.dart';

const double feetPerMeter = 3.28084;

String formatAge(int? ms) {
  if (ms == null) return '--';
  final s = ms / 1000.0;
  if (s < 60) return '${s.toStringAsFixed(s < 10 ? 1 : 0)} s';
  final m = s ~/ 60;
  return '${m}m ${(s % 60).toStringAsFixed(0)}s';
}

String connectionLabel(LinkConnection c) => switch (c) {
      LinkConnection.disconnected => 'Not connected',
      LinkConnection.connecting => 'Connecting...',
      LinkConnection.connected => 'Connected',
      LinkConnection.retrying => 'Cannot reach it, retrying',
      LinkConnection.finished => 'Replay finished',
    };

String statusLabel(LinkStatus s) => switch (s) {
      LinkStatus.waiting => 'WAITING',
      LinkStatus.live => 'LIVE',
      LinkStatus.stale => 'STALE',
      LinkStatus.lost => 'LOST',
    };

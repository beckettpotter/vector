import 'dart:async';

import 'package:flutter/foundation.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../protocol/packet.dart';
import 'flight_store.dart';

/// Records flights automatically from the live link.
///
/// Starts on the first packet that is not on the pad (boost, or later if the
/// app joined mid-flight) and keeps up to 30 pad packets from before it, so
/// the pad period is saved too but an idle tracker on the pad is not.
/// Ends 15 s (tracker time) after the first landed packet, when the link is
/// lost for 30 s, on disconnect, or on a new session. Under 10 packets is discarded.
class Recorder extends ChangeNotifier {
  final FlightStore store;
  final LinkController link;
  final String Function(int rocketId, DateTime startedAtUtc)? nameFor;
  final DateTime Function() clockUtc;

  static const int padBufferSize = 30;
  static const int afterLandingMs = 15000;

  Recorder({required this.store, required this.link, this.nameFor, DateTime Function()? clockUtc})
      : clockUtc = clockUtc ?? (() => DateTime.now().toUtc()) {
    link.frameListeners.add(_onFrame);
    link.addListener(_onLinkChange);
  }

  final List<GroundFrame> _padBuffer = [];
  FlightWriter? _writer;
  int? _landedAtMs;
  Future<void> _pending = Future.value();

  bool get recording => _writer != null;
  int get recordedPackets => _writer?.count ?? 0;

  /// Bumps whenever a flight is saved, so the history list can refresh.
  int savedCount = 0;
  FlightRecord? lastSaved;

  void _onFrame(GroundFrame frame, bool newSession) {
    // Serialised so file creation and finishing never overlap.
    _pending = _pending.then((_) => _handle(frame, newSession));
  }

  Future<void> _handle(GroundFrame frame, bool newSession) async {
    final p = frame.packet;
    if (newSession) {
      await _finish();
      _padBuffer.clear();
    }
    if (_writer == null) {
      if (p.phase == Phase.pad) {
        _padBuffer.add(frame);
        if (_padBuffer.length > padBufferSize) _padBuffer.removeAt(0);
        return;
      }
      if (p.phase == Phase.landed) return; // joined after landing: nothing to record
      final started = clockUtc();
      final meta = FlightMeta(
        name: nameFor?.call(p.rocketId, started) ?? defaultFlightName(p.rocketId, started),
        rocketId: p.rocketId,
        startedAtUtc: started,
      );
      _writer = await store.startFlight(meta);
      for (final f in _padBuffer) {
        _writer!.append(f);
      }
      _padBuffer.clear();
      _landedAtMs = null;
      notifyListeners();
    }
    _writer!.append(frame);
    if (p.phase == Phase.landed) {
      _landedAtMs ??= p.timeMs;
      if (p.timeMs - _landedAtMs! >= afterLandingMs) await _finish();
    }
  }

  void _onLinkChange() {
    if (_writer == null) return;
    if (link.monitor.status == LinkStatus.lost || !link.isActive) {
      _pending = _pending.then((_) => _finish());
    }
  }

  Future<void> _finish() async {
    final w = _writer;
    if (w == null) return;
    _writer = null;
    _landedAtMs = null;
    final saved = await w.finish();
    if (saved != null) {
      lastSaved = saved;
      savedCount++;
    }
    notifyListeners();
  }

  /// Finish any flight in progress (used on shutdown and in tests).
  Future<void> flush() async {
    await _pending;
    await _finish();
  }

  @override
  void dispose() {
    link.frameListeners.remove(_onFrame);
    link.removeListener(_onLinkChange);
    super.dispose();
  }
}

String defaultFlightName(int rocketId, DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Rocket $rocketId, ${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)} UTC';
}

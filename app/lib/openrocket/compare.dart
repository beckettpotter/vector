import 'dart:math' as math;

import '../protocol/flight_stats.dart';
import '../protocol/packet.dart';
import 'projection.dart';

/// Real flight versus OpenRocket. The real data is never resampled: the
/// prediction is read at each packet's own time. Time zero is the first boost
/// packet; [offsetS] is the user's nudge (packets are 1 Hz, so launch can be
/// up to 1 s off). Real altitude is baro_alt_cm (above the pad reference),
/// OpenRocket's is above the launch site.

/// Seconds since launch for a packet, with the nudge applied.
double flightTimeS(Packet p, int launchMs, double offsetS) => (p.timeMs - launchMs) / 1000.0 + offsetS;

int? launchTimeMs(List<Packet> packets) {
  for (final p in packets) {
    if (p.phase == Phase.boost) return p.timeMs;
  }
  return null;
}

/// The live comparison at one packet.
class LiveComparison {
  final double tS;
  final double predictedAltM;
  final double predictedVvelMs;
  final double altDiffM; // real minus predicted
  const LiveComparison(this.tS, this.predictedAltM, this.predictedVvelMs, this.altDiffM);

  /// Within this many meters counts as "on the prediction".
  double get toleranceM => math.max(5.0, 0.03 * predictedAltM.abs());
  bool get above => altDiffM > toleranceM;
  bool get below => altDiffM < -toleranceM;
}

LiveComparison? liveComparison(Projection proj, List<Packet> session, {double offsetS = 0}) {
  if (session.isEmpty) return null;
  final launch = launchTimeMs(session);
  if (launch == null) return null;
  final p = session.last;
  final t = flightTimeS(p, launch, offsetS);
  final alt = proj.altAt(t);
  return LiveComparison(t, alt, proj.vvelAt(t), p.baroAltM - alt);
}

class ComparisonRow {
  final String label;
  final String unit;
  final double predicted;
  final double actual;

  /// Why this row is not compared (shown in grey instead of a difference).
  final String? excluded;
  const ComparisonRow(this.label, this.unit, this.predicted, this.actual, {this.excluded});

  double get difference => actual - predicted;
  double get percent => predicted == 0 ? double.nan : 100 * difference / predicted;
  bool get comparable => excluded == null && !predicted.isNaN && !actual.isNaN;
}

class PhaseError {
  final String phase;
  final int packets;
  final double rmsM;
  final double meanM; // real minus predicted, average
  const PhaseError(this.phase, this.packets, this.rmsM, this.meanM);
}

class FlightComparison {
  final List<ComparisonRow> rows;
  final double rmsAltM;
  final List<PhaseError> phases;
  final List<String> summary;
  const FlightComparison(this.rows, this.rmsAltM, this.phases, this.summary);
}

const String noRecoveryLabel = 'Simulation has no recovery device';

FlightComparison? compareFlight(Projection proj, List<Packet> packets, {double offsetS = 0}) {
  final launch = launchTimeMs(packets);
  if (launch == null) return null;
  FlightStats? stats;
  try {
    stats = computeStats(packets);
  } on StateError {
    stats = null; // no landing: compare what there is
  }
  var peak = packets.first;
  for (final p in packets) {
    if (p.baroAltCm > peak.baroAltCm) peak = p;
  }
  final apogee = peak.baroAltM;
  final toApogee = (peak.timeMs - launch) / 1000.0 + offsetS;
  final maxV = packets.map((p) => p.vspeedMs.abs()).reduce(math.max);
  final noRec = proj.noRecoveryDevice ? noRecoveryLabel : null;

  final rows = <ComparisonRow>[
    ComparisonRow('Apogee', 'm', proj.apogeeM, apogee),
    ComparisonRow('Time to apogee', 's', proj.apogeeT, toApogee),
    ComparisonRow('Max vertical speed', 'm/s', proj.maxVerticalSpeedMs, maxV),
    ComparisonRow('Descent rate', 'm/s', proj.descentRateMs, stats?.descentRateMs ?? double.nan, excluded: noRec),
    ComparisonRow('Flight time', 's', proj.groundHitT, stats == null ? double.nan : stats.flightTimeS + offsetS,
        excluded: noRec),
    ComparisonRow('Landing distance', 'm', proj.driftM ?? double.nan, stats?.landingDistanceM ?? double.nan,
        excluded: noRec),
  ];

  // Altitude error at each real packet from launch until landing (or until the
  // simulation ends, whichever is first).
  final groups = <String, List<double>>{'Boost': [], 'Coast': [], 'Descent': []};
  final all = <double>[];
  for (final p in packets) {
    if (p.timeMs < launch || p.phase == Phase.landed || p.phase == Phase.pad) continue;
    final t = flightTimeS(p, launch, offsetS);
    if (t > proj.groundHitT) continue;
    final e = p.baroAltM - proj.altAt(t);
    if (e.isNaN) continue;
    all.add(e);
    final g = switch (p.phase) { Phase.boost => 'Boost', Phase.descent => 'Descent', _ => 'Coast' };
    groups[g]!.add(e);
  }
  double rms(List<double> v) => v.isEmpty ? double.nan : math.sqrt(v.fold<double>(0, (s, e) => s + e * e) / v.length);
  double mean(List<double> v) => v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
  final phases = [for (final MapEntry(:key, :value) in groups.entries) PhaseError(key, value.length, rms(value), mean(value))];

  return FlightComparison(rows, rms(all), phases, _summary(rows, proj));
}

/// Plain sentences from the numbers only; no claims about causes.
List<String> _summary(List<ComparisonRow> rows, Projection proj) {
  String pct(ComparisonRow r) => '${r.percent.abs().toStringAsFixed(1)}%';
  final out = <String>[];
  final a = rows[0];
  if (a.comparable) {
    out.add(a.percent.abs() < 0.5
        ? 'Apogee matched the prediction (${a.actual.toStringAsFixed(1)} m).'
        : 'Flew ${pct(a)} ${a.difference > 0 ? 'higher' : 'lower'} than predicted '
            '(${a.actual.toStringAsFixed(1)} m against ${a.predicted.toStringAsFixed(1)} m).');
  }
  final t = rows[1];
  if (t.comparable && t.difference.abs() >= 0.5) {
    out.add('Reached apogee ${t.difference.abs().toStringAsFixed(1)} s ${t.difference > 0 ? 'later' : 'earlier'} '
        'than predicted.');
  }
  final d = rows[3];
  if (d.comparable && d.difference.abs() >= 0.2) {
    out.add('Came down ${d.difference.abs().toStringAsFixed(1)} m/s ${d.difference > 0 ? 'faster' : 'slower'} '
        'than predicted.');
  }
  if (proj.noRecoveryDevice) {
    out.add('Descent and landing were not compared: the simulation has no recovery device.');
  }
  return out;
}

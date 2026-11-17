import 'dart:math' as math;

import 'packet.dart';

/// Definitions: protocol/PROTOCOL.md "Flight statistics". Reference: tools/flight_stats.py.
const double earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;

double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final p1 = _rad(lat1), p2 = _rad(lat2);
  final dPhi = p2 - p1;
  final dLmb = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dPhi / 2), 2) +
      math.cos(p1) * math.cos(p2) * math.pow(math.sin(dLmb / 2), 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(a));
}

class FlightStats {
  final double apogeeM;
  final double timeToApogeeS;
  final double maxVerticalSpeedMs;
  final double descentRateMs;
  final double flightTimeS;
  final double landingDistanceM;
  final int packetCount;

  const FlightStats({
    required this.apogeeM,
    required this.timeToApogeeS,
    required this.maxVerticalSpeedMs,
    required this.descentRateMs,
    required this.flightTimeS,
    required this.landingDistanceM,
    required this.packetCount,
  });
}

/// Values are unrounded; round only for display.
FlightStats computeStats(List<Packet> packets) {
  Packet? firstOf(Phase ph) {
    for (final p in packets) {
      if (p.phase == ph) return p;
    }
    return null;
  }

  final launch = firstOf(Phase.boost);
  final landed = firstOf(Phase.landed);
  if (launch == null || landed == null) {
    throw StateError('flight has no boost packet or no landed packet');
  }

  var peak = packets.first;
  for (final p in packets) {
    if (p.baroAltCm > peak.baroAltCm) peak = p; // first packet wins a tie
  }

  final fixes = packets.where((p) => p.has3dFix).toList();
  final landedFixes = fixes.where((p) => p.phase == Phase.landed).toList();
  final descent = packets.where((p) => p.phase == Phase.descent).toList();

  final landingDistanceM = (fixes.isEmpty || landedFixes.isEmpty)
      ? double.nan
      : haversineM(fixes.first.latDeg, fixes.first.lonDeg, landedFixes.last.latDeg, landedFixes.last.lonDeg);
  final descentRateMs = descent.isEmpty
      ? double.nan
      : -descent.fold<int>(0, (s, p) => s + p.vspeedCms) / descent.length / 100.0;

  return FlightStats(
    apogeeM: peak.baroAltCm / 100.0,
    timeToApogeeS: (peak.timeMs - launch.timeMs) / 1000.0,
    maxVerticalSpeedMs: packets.map((p) => p.vspeedCms.abs()).reduce(math.max) / 100.0,
    descentRateMs: descentRateMs,
    flightTimeS: (landed.timeMs - launch.timeMs) / 1000.0,
    landingDistanceM: landingDistanceM,
    packetCount: packets.length,
  );
}

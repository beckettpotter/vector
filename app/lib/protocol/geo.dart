import 'dart:math' as math;

import 'flight_stats.dart' show earthRadiusM;
import 'packet.dart';

/// Flat-earth helpers for the track plot. Accurate enough within about 10 km
/// of the pad, which covers any L1 to L3 flight.
class EastNorth {
  final double eastM;
  final double northM;
  const EastNorth(this.eastM, this.northM);
  double get distanceM => math.sqrt(eastM * eastM + northM * northM);
}

const double _degToRad = math.pi / 180.0;

EastNorth toEastNorth(double padLat, double padLon, double lat, double lon) => EastNorth(
      (lon - padLon) * _degToRad * earthRadiusM * math.cos(padLat * _degToRad),
      (lat - padLat) * _degToRad * earthRadiusM,
    );

const List<double> ringStepsM = [100, 250, 500, 1000, 2000, 5000, 10000];

/// Distance rings to draw: every standard ring up to the first one that
/// contains [maxDistanceM].
List<double> chooseRings(double maxDistanceM) {
  final rings = <double>[];
  for (final r in ringStepsM) {
    rings.add(r);
    if (r >= maxDistanceM) break;
  }
  return rings;
}

String ringLabel(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km' : '${m.toStringAsFixed(0)} m';

class TrackPoint {
  final EastNorth pos;
  final Phase phase;

  /// True when GPS fixes were missing just before this point (draw dashed).
  final bool gapBefore;
  const TrackPoint(this.pos, this.phase, this.gapBefore);
}

class Track {
  final Packet? pad;
  final List<TrackPoint> points;
  final Packet? lastFix;
  final Packet? latest;
  const Track(this.pad, this.points, this.lastFix, this.latest);

  bool get gpsLost => latest != null && !latest!.has3dFix;
  EastNorth? get latestPos => points.isEmpty ? null : points.last.pos;
}

/// Builds the track from a session's packets. Only 3D-fix packets become
/// points: without a fix the tracker repeats the old position, and drawing
/// those would show the rocket parked at the pad during boost.
Track buildTrack(List<Packet> packets) {
  Packet? pad;
  Packet? lastFix;
  final points = <TrackPoint>[];
  var missed = false;
  for (final p in packets) {
    if (!p.has3dFix) {
      if (pad != null) missed = true;
      continue;
    }
    pad ??= p;
    lastFix = p;
    points.add(TrackPoint(toEastNorth(pad.latDeg, pad.lonDeg, p.latDeg, p.lonDeg), p.phase, missed));
    missed = false;
  }
  return Track(pad, points, lastFix, packets.isEmpty ? null : packets.last);
}

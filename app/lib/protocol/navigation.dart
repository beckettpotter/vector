import 'dart:math' as math;

import 'packet.dart';

export 'flight_stats.dart' show haversineM;

/// Initial great-circle bearing from point 1 to point 2: 0 to 360, 0 is
/// north, clockwise.
double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  const r = math.pi / 180;
  final p1 = lat1 * r, p2 = lat2 * r, dl = (lon2 - lon1) * r;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) / r + 360) % 360;
}

const _cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

/// Eight-point compass letters; each sector is 45 degrees wide, centred on its direction.
String cardinal(double deg) => _cardinals[(((deg % 360) + 22.5) ~/ 45) % 8];

class LastFix {
  final Packet packet;

  /// Tracker time between this fix and the newest packet, in ms.
  final int ageMs;
  const LastFix(this.packet, this.ageMs);
}

/// The most recent packet with a 3D fix, and how much older it is than the newest packet.
LastFix? lastKnownFix(List<Packet> packets) {
  for (var i = packets.length - 1; i >= 0; i--) {
    if (packets[i].has3dFix) return LastFix(packets[i], packets.last.timeMs - packets[i].timeMs);
  }
  return null;
}

const _cardinals16 = [
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
];

/// Sixteen-point compass letters (22.5-degree sectors), used on screen.
String cardinal16(double deg) => _cardinals16[(((deg % 360) + 11.25) ~/ 22.5) % 16];

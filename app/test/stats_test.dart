import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/protocol/flight_file.dart';
import 'package:vector/protocol/flight_stats.dart';
import 'package:vector/protocol/packet.dart';

void main() {
  final frames = parseHexFlight(File('../protocol/sample_flight.hex').readAsStringSync());
  final packets = frames.map((f) => f.packet).toList();

  test('haversine known distances', () {
    expect(haversineM(0, 0, 0, 0), 0.0);
    expect(haversineM(0, 0, 1, 0), closeTo(111194.9, 1.0));
  });

  test('sample flight reproduces expected_stats.json', () {
    final expected = (jsonDecode(File('../protocol/expected_stats.json').readAsStringSync())
        as Map<String, dynamic>)['stats'] as Map<String, dynamic>;
    final s = computeStats(packets);
    expect(s.apogeeM, closeTo(expected['apogee_m'], 0.1));
    expect(s.timeToApogeeS, closeTo(expected['time_to_apogee_s'], 0.1));
    expect(s.maxVerticalSpeedMs, closeTo(expected['max_vertical_speed_ms'], 0.1));
    expect(s.descentRateMs, closeTo(expected['descent_rate_ms'], 0.1));
    expect(s.flightTimeS, closeTo(expected['flight_time_s'], 0.1));
    expect(s.landingDistanceM, closeTo(expected['landing_distance_m'], 0.1));
    expect(s.packetCount, expected['packet_count']);
  });

  test('a flight with no landed packet throws', () {
    final noLanding = packets.where((p) => p.phase != Phase.landed).toList();
    expect(() => computeStats(noLanding), throwsStateError);
  });

  test('a flight with no boost packet throws', () {
    final noBoost = packets.where((p) => p.phase != Phase.boost).toList();
    expect(() => computeStats(noBoost), throwsStateError);
  });
}

import '../protocol/packet.dart';

/// Formats integer [value] / 10^[decimals] exactly (no floating point), so
/// the CSV matches protocol/sample_flight.csv byte for byte.
String fixedFromInt(int value, int decimals) {
  final neg = value < 0;
  final digits = value.abs().toString().padLeft(decimals + 1, '0');
  final cut = digits.length - decimals;
  return '${neg ? '-' : ''}${digits.substring(0, cut)}.${digits.substring(cut)}';
}

const String csvHeader =
    'seq,time_ms,rocket_id,lat_deg,lon_deg,gps_alt_m,baro_alt_m,vspeed_ms,battery_mv,sats,fix_type,phase,armed,rssi_dbm,snr_db';

/// The exact format of protocol/sample_flight.csv (the test file is the source of truth).
String flightToCsv(List<GroundFrame> frames) {
  final b = StringBuffer('$csvHeader\n');
  for (final f in frames) {
    final p = f.packet;
    b.write([
      p.seq,
      p.timeMs,
      p.rocketId,
      fixedFromInt(p.latE7, 7),
      fixedFromInt(p.lonE7, 7),
      fixedFromInt(p.gpsAltCm, 2),
      fixedFromInt(p.baroAltCm, 2),
      fixedFromInt(p.vspeedCms, 2),
      p.batteryMv,
      p.sats,
      p.fixType,
      p.phase.name,
      p.armed ? 1 : 0,
      f.rssiDbm,
      f.snrDb,
    ].join(','));
    b.write('\n');
  }
  return b.toString();
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _coord(Packet p) => '${fixedFromInt(p.lonE7, 7)},${fixedFromInt(p.latE7, 7)},${fixedFromInt(p.gpsAltCm, 2)}';

/// KML for Google Earth: the 3D-fix track (lon,lat,alt with altitude in meters
/// above sea level), a pad placemark and a landing placemark.
String flightToKml(List<GroundFrame> frames, String name) {
  final fixes = [for (final f in frames) if (f.packet.has3dFix) f.packet];
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
    ..writeln('<Document>')
    ..writeln('  <name>${_xml(name)}</name>')
    ..writeln('  <Style id="track"><LineStyle><color>ffffe500</color><width>4</width></LineStyle></Style>');
  if (fixes.isNotEmpty) {
    final pad = fixes.first;
    final landedFixes = fixes.where((p) => p.phase == Phase.landed);
    final landing = landedFixes.isNotEmpty ? landedFixes.last : fixes.last;
    b
      ..writeln('  <Placemark>')
      ..writeln('    <name>Track</name>')
      ..writeln('    <styleUrl>#track</styleUrl>')
      ..writeln('    <LineString>')
      ..writeln('      <altitudeMode>absolute</altitudeMode>')
      ..writeln('      <coordinates>')
      ..writeln([for (final p in fixes) '        ${_coord(p)}'].join('\n'))
      ..writeln('      </coordinates>')
      ..writeln('    </LineString>')
      ..writeln('  </Placemark>');
    for (final (label, p) in [('Pad', pad), (landedFixes.isNotEmpty ? 'Landing' : 'Last known position', landing)]) {
      b
        ..writeln('  <Placemark>')
        ..writeln('    <name>$label</name>')
        ..writeln('    <Point><altitudeMode>clampToGround</altitudeMode><coordinates>${_coord(p)}</coordinates></Point>')
        ..writeln('  </Placemark>');
    }
  }
  b
    ..writeln('</Document>')
    ..writeln('</kml>');
  return b.toString();
}

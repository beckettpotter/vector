import 'dart:convert';
import 'dart:math' as math;

/// OpenRocket simulation CSV import. Rules: docs/V2_PLAN.md item a. Only the
/// CSV is read (never the .ork). Only the columns below are used; the rest of
/// the file is ignored.
const double standardGravity = 9.80665;

class OpenRocketFormatException implements Exception {
  final String message;
  const OpenRocketFormatException(this.message);
  @override
  String toString() => message;
}

/// A named moment in the simulation, e.g. ('BURNOUT', 2.398).
class SimEvent {
  final String name;
  final double t;
  const SimEvent(this.name, this.t);
}

/// What OpenRocket predicts, kept small enough to save inside a flight file.
/// Time zero is OpenRocket's t = 0 (ignition), lined up with the first boost
/// packet. Altitude is above the launch site. Missing values are NaN.
class Projection {
  String name;
  final List<double> t;
  final List<double> alt;
  final List<double> vvel;
  final List<SimEvent> events;
  final List<String> warnings;

  // Single numbers. null means the file did not have the column or event.
  final double apogeeM;
  final double apogeeT;
  final double? burnoutT, burnoutAltM, burnoutVvelMs;
  final double maxVerticalSpeedMs;
  final double? maxTotalSpeedMs, maxAccelG, maxMach;
  final double descentRateMs;
  final double groundHitT;
  final double? driftM, driftDirDeg;
  final double? stabilityRodExitCal, stabilityMinCal;

  Projection({
    required this.name,
    required this.t,
    required this.alt,
    required this.vvel,
    required this.events,
    required this.warnings,
    required this.apogeeM,
    required this.apogeeT,
    this.burnoutT,
    this.burnoutAltM,
    this.burnoutVvelMs,
    required this.maxVerticalSpeedMs,
    this.maxTotalSpeedMs,
    this.maxAccelG,
    this.maxMach,
    required this.descentRateMs,
    required this.groundHitT,
    this.driftM,
    this.driftDirDeg,
    this.stabilityRodExitCal,
    this.stabilityMinCal,
  });

  /// OpenRocket warned that the simulation has no parachute or streamer, so the
  /// descent numbers are the airframe falling, not a recovery descent.
  bool get noRecoveryDevice => warnings.any((w) => w.toLowerCase().contains('no recovery device'));

  /// OpenRocket's own stability number at rod exit is below 1 caliber.
  bool get marginalStability => stabilityRodExitCal != null && stabilityRodExitCal! < 1.0;

  double altAt(double time) => interpolate(t, alt, time);
  double vvelAt(double time) => interpolate(t, vvel, time);

  Map<String, dynamic> toJson() {
    double r(double v, int places) => v.isNaN ? double.nan : double.parse(v.toStringAsFixed(places));
    List<Object?> list(List<double> v, int places) => [for (final x in v) x.isNaN ? null : r(x, places)];
    return {
      'name': name,
      't': list(t, 4),
      'alt': list(alt, 2),
      'vvel': list(vvel, 2),
      'events': [for (final e in events) {'name': e.name, 't': e.t}],
      'warnings': warnings,
      'apogeeM': apogeeM,
      'apogeeT': apogeeT,
      'burnoutT': burnoutT,
      'burnoutAltM': burnoutAltM,
      'burnoutVvelMs': burnoutVvelMs,
      'maxVerticalSpeedMs': maxVerticalSpeedMs,
      'maxTotalSpeedMs': maxTotalSpeedMs,
      'maxAccelG': maxAccelG,
      'maxMach': maxMach,
      'descentRateMs': descentRateMs.isNaN ? null : descentRateMs,
      'groundHitT': groundHitT,
      'driftM': driftM,
      'driftDirDeg': driftDirDeg,
      'stabilityRodExitCal': stabilityRodExitCal,
      'stabilityMinCal': stabilityMinCal,
    };
  }

  factory Projection.fromJson(Map<String, dynamic> j) {
    List<double> list(String k) => [for (final x in j[k] as List) (x as num?)?.toDouble() ?? double.nan];
    double? opt(String k) => (j[k] as num?)?.toDouble();
    return Projection(
      name: j['name'] as String? ?? 'Projection',
      t: list('t'),
      alt: list('alt'),
      vvel: list('vvel'),
      events: [
        for (final e in (j['events'] as List? ?? const []))
          SimEvent((e as Map)['name'] as String, (e['t'] as num).toDouble()),
      ],
      warnings: [for (final w in (j['warnings'] as List? ?? const [])) w as String],
      apogeeM: (j['apogeeM'] as num).toDouble(),
      apogeeT: (j['apogeeT'] as num).toDouble(),
      burnoutT: opt('burnoutT'),
      burnoutAltM: opt('burnoutAltM'),
      burnoutVvelMs: opt('burnoutVvelMs'),
      maxVerticalSpeedMs: (j['maxVerticalSpeedMs'] as num).toDouble(),
      maxTotalSpeedMs: opt('maxTotalSpeedMs'),
      maxAccelG: opt('maxAccelG'),
      maxMach: opt('maxMach'),
      descentRateMs: opt('descentRateMs') ?? double.nan,
      groundHitT: (j['groundHitT'] as num).toDouble(),
      driftM: opt('driftM'),
      driftDirDeg: opt('driftDirDeg'),
      stabilityRodExitCal: opt('stabilityRodExitCal'),
      stabilityMinCal: opt('stabilityMinCal'),
    );
  }
}

/// Linear interpolation by time; never assumes a fixed step. Before the first
/// or after the last time it holds the end value. A NaN neighbour gives the
/// other neighbour (or NaN if both are missing).
double interpolate(List<double> t, List<double> y, double x) {
  if (t.isEmpty) return double.nan;
  if (x <= t.first) return y.first;
  if (x >= t.last) return y.last;
  var lo = 0, hi = t.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (t[mid] <= x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = y[lo], b = y[hi];
  if (a.isNaN) return b;
  if (b.isNaN) return a;
  final span = t[hi] - t[lo];
  if (span <= 0) return a;
  return a + (b - a) * (x - t[lo]) / span;
}

/// 'Stability margin calibers (​)' -> 'stability margin calibers'.
String _columnKey(String header) {
  var s = header.replaceAll('​', '').replaceAll('﻿', '').trim();
  if (s.startsWith('#')) s = s.substring(1).trim();
  final paren = s.lastIndexOf('(');
  if (paren > 0) s = s.substring(0, paren);
  return s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

final _eventLine = RegExp(r'^#\s*Event\s+(\S+)\s+occurred at t\s*=\s*([-+0-9.eE]+)\s*seconds(?:\s*:\s*(.*))?$');

/// Parse an OpenRocket CSV export. [name] is what Beckett calls it (default:
/// the file name). Throws [OpenRocketFormatException] with plain words.
Projection parseOpenRocketCsv(List<int> bytes, {required String name}) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  final lines = const LineSplitter().convert(text);

  // Header: the first line (commented or not) whose first cell is "Time (...".
  var headerAt = -1;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trimLeft();
    final body = l.startsWith('#') ? l.substring(1).trimLeft() : l;
    if (RegExp(r'^time\s*\(', caseSensitive: false).hasMatch(body)) {
      headerAt = i;
      break;
    }
  }
  if (headerAt < 0) {
    throw const OpenRocketFormatException(
        "This doesn't look like an OpenRocket simulation export: no 'Time' column was found. In OpenRocket, "
        'open the simulation, choose Export, tick Time and Altitude, and save as CSV.');
  }
  var header = lines[headerAt].trim();
  if (header.startsWith('#')) header = header.substring(1).trim();

  // Separator: comma, semicolon, tab or space (OpenRocket offers all four).
  final String? sep;
  final List<String> names;
  if (header.contains('\t')) {
    sep = '\t';
  } else if (header.contains(';')) {
    sep = ';';
  } else if (header.contains(',')) {
    sep = ',';
  } else {
    sep = null; // spaces: every column name ends with "(unit)", so split after ')'
  }
  names = sep == null ? header.split(RegExp(r'(?<=\))\s+')) : header.split(sep);
  final keys = [for (final n in names) _columnKey(n)];
  int? col(String key) {
    final i = keys.indexOf(key);
    return i < 0 ? null : i;
  }

  final iTime = col('time');
  final iAlt = col('altitude');
  for (final (i, label) in [(iTime, 'Time'), (iAlt, 'Altitude')]) {
    if (i == null) {
      throw OpenRocketFormatException("This file has no '$label' column. In OpenRocket's export dialog, tick "
          "'$label' and export the CSV again.");
    }
  }

  // Comments: events (between data rows) and the warning block at the top.
  final events = <SimEvent>[];
  final warnings = <String>[];
  var inWarnings = false;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trim();
    if (!l.startsWith('#') || i == headerAt) continue;
    final m = _eventLine.firstMatch(l);
    if (m != null) {
      final t = double.tryParse(m.group(2)!);
      if (t != null) events.add(SimEvent(m.group(1)!, t));
      final note = m.group(3)?.trim();
      if (m.group(1) == 'SIM_WARN' && note != null && note.isNotEmpty && !warnings.contains(note)) {
        warnings.add(note);
      }
      inWarnings = false;
      continue;
    }
    if (l.toLowerCase().startsWith('# simulation warnings')) {
      inWarnings = true;
      continue;
    }
    if (inWarnings) {
      final w = l.substring(1).trim();
      if (w.isEmpty) {
        inWarnings = false;
      } else if (!warnings.contains(w)) {
        warnings.add(w);
      }
    }
  }

  // Data rows.
  final rows = <List<double>>[];
  for (var i = headerAt + 1; i < lines.length; i++) {
    final l = lines[i].trim();
    if (l.isEmpty || l.startsWith('#')) continue;
    final cells = sep == null ? l.split(RegExp(r'\s+')) : l.split(sep);
    final row = [for (final c in cells) double.tryParse(c.trim()) ?? double.nan]; // 'NaN' parses as NaN
    if (row.length <= iTime! || row[iTime].isNaN) continue;
    rows.add(row);
  }
  if (rows.isEmpty) throw const OpenRocketFormatException('The file has a header but no data rows.');

  // Times should be strictly increasing; if not, sort and drop repeats.
  var increasing = true;
  for (var i = 1; i < rows.length; i++) {
    if (rows[i][iTime!] <= rows[i - 1][iTime]) increasing = false;
  }
  if (!increasing) {
    rows.sort((a, b) => a[iTime!].compareTo(b[iTime]));
    for (var i = rows.length - 1; i > 0; i--) {
      if (rows[i][iTime!] == rows[i - 1][iTime]) rows.removeAt(i);
    }
  }

  List<double>? series(String key) {
    final i = col(key);
    if (i == null) return null;
    return [for (final r in rows) i < r.length ? r[i] : double.nan];
  }

  final t = series('time')!;
  final alt = series('altitude')!;
  final vvel = series('vertical velocity') ?? _derivative(t, alt);
  final total = series('total velocity');
  final acc = series('vertical acceleration');
  final latDist = series('lateral distance');
  final latDir = series('lateral direction');
  final east = series('position east of launch');
  final north = series('position north of launch');
  final stab = series('stability margin calibers');
  final mach = series('mach number');

  double? maxOf(List<double>? v, {bool abs = false}) {
    if (v == null) return null;
    double? m;
    for (final x in v) {
      if (x.isNaN) continue;
      final y = abs ? x.abs() : x;
      if (m == null || y > m) m = y;
    }
    return m;
  }

  double? eventT(String n) {
    for (final e in events) {
      if (e.name == n) return e.t;
    }
    return null;
  }

  var peak = 0;
  for (var i = 1; i < alt.length; i++) {
    if (!alt[i].isNaN && (alt[peak].isNaN || alt[i] > alt[peak])) peak = i;
  }
  final apogeeT = t[peak];
  final groundT = eventT('GROUND_HIT') ?? t.last;
  final burnT = eventT('BURNOUT');

  // Descent rate: average over the middle 80% of the fall (apogee to ground),
  // skipping the turn-over at the top and the last moments.
  final fall = groundT - apogeeT;
  var descent = double.nan;
  if (fall > 1) {
    final t1 = apogeeT + 0.1 * fall, t2 = groundT - 0.1 * fall;
    descent = (interpolate(t, alt, t1) - interpolate(t, alt, t2)) / (t2 - t1);
  }

  double? at(List<double>? v, double time) {
    if (v == null) return null;
    final x = interpolate(t, v, time);
    return x.isNaN ? null : x;
  }

  double? drift = at(latDist, groundT);
  double? dir = at(latDir, groundT);
  if (drift == null && east != null && north != null) {
    final e = at(east, groundT), n = at(north, groundT);
    if (e != null && n != null) {
      drift = math.sqrt(e * e + n * n);
      dir = (math.atan2(e, n) * 180 / math.pi + 360) % 360;
    }
  }

  // Stability at rod exit: the first value at or after the LAUNCHROD event.
  double? stabRod;
  final rodT = eventT('LAUNCHROD');
  if (stab != null && rodT != null) {
    stabRod = at(stab, rodT);
    if (stabRod == null) {
      for (var i = 0; i < t.length; i++) {
        if (t[i] >= rodT && !stab[i].isNaN) {
          stabRod = stab[i];
          break;
        }
      }
    }
  }
  double? stabMin;
  if (stab != null) {
    for (final x in stab) {
      if (!x.isNaN && (stabMin == null || x < stabMin)) stabMin = x;
    }
  }

  final maxAcc = maxOf(acc);
  return Projection(
    name: name,
    t: t,
    alt: alt,
    vvel: vvel,
    events: events,
    warnings: warnings,
    apogeeM: alt[peak],
    apogeeT: apogeeT,
    burnoutT: burnT,
    burnoutAltM: burnT == null ? null : at(alt, burnT),
    burnoutVvelMs: burnT == null ? null : at(vvel, burnT),
    maxVerticalSpeedMs: maxOf(vvel, abs: true) ?? double.nan,
    maxTotalSpeedMs: maxOf(total),
    maxAccelG: maxAcc == null ? null : maxAcc / standardGravity,
    maxMach: maxOf(mach),
    descentRateMs: descent,
    groundHitT: groundT,
    driftM: drift,
    driftDirDeg: dir,
    stabilityRodExitCal: stabRod,
    stabilityMinCal: stabMin,
  );
}

/// Vertical speed from altitude when the file has no 'Vertical velocity' column.
List<double> _derivative(List<double> t, List<double> y) => [
      for (var i = 0; i < t.length; i++)
        i == 0 || t[i] == t[i - 1] ? 0.0 : (y[i] - y[i - 1]) / (t[i] - t[i - 1]),
    ];

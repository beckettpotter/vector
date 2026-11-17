import 'dart:convert';
import 'dart:io';

import '../protocol/packet.dart';

/// A flight is two plain files in the flights folder:
///   `flight_<rocketId>_<yyyyMMdd_HHmmss>.hex`   one ground frame as hex per line
///   `flight_<rocketId>_<yyyyMMdd_HHmmss>.json`  {name, rocketId, startedAtUtc, padLat, padLon, notes}
/// No database, so a flight can be copied, emailed or opened in any editor.
class FlightMeta {
  String name;
  final int rocketId;
  final DateTime startedAtUtc;
  double? padLat;
  double? padLon;
  String notes;

  FlightMeta({
    required this.name,
    required this.rocketId,
    required this.startedAtUtc,
    this.padLat,
    this.padLon,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rocketId': rocketId,
        'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
        'padLat': padLat,
        'padLon': padLon,
        'notes': notes,
      };

  factory FlightMeta.fromJson(Map<String, dynamic> j) => FlightMeta(
        name: j['name'] as String? ?? 'Flight',
        rocketId: (j['rocketId'] as num?)?.toInt() ?? 0,
        startedAtUtc: DateTime.parse(j['startedAtUtc'] as String).toUtc(),
        padLat: (j['padLat'] as num?)?.toDouble(),
        padLon: (j['padLon'] as num?)?.toDouble(),
        notes: j['notes'] as String? ?? '',
      );
}

class FlightRecord {
  final String id; // file name without extension
  final FlightMeta meta;
  final File hexFile;
  final File jsonFile;
  const FlightRecord(this.id, this.meta, this.hexFile, this.jsonFile);
}

String _two(int v) => v.toString().padLeft(2, '0');
String fileStamp(DateTime t) {
  final u = t.toUtc();
  return '${u.year}${_two(u.month)}${_two(u.day)}_${_two(u.hour)}${_two(u.minute)}${_two(u.second)}';
}

class FlightStore {
  final Directory dir;
  FlightStore(this.dir);

  Future<FlightWriter> startFlight(FlightMeta meta) async {
    await dir.create(recursive: true);
    var id = 'flight_${meta.rocketId}_${fileStamp(meta.startedAtUtc)}';
    var n = 2;
    while (File('${dir.path}/$id.hex').existsSync()) {
      id = 'flight_${meta.rocketId}_${fileStamp(meta.startedAtUtc)}_${n++}';
    }
    final record = FlightRecord(id, meta, File('${dir.path}/$id.hex'), File('${dir.path}/$id.json'));
    await _writeMeta(record);
    return FlightWriter._(record, record.hexFile.openSync(mode: FileMode.writeOnly), this);
  }

  Future<void> _writeMeta(FlightRecord r) =>
      r.jsonFile.writeAsString('${const JsonEncoder.withIndent('  ').convert(r.meta.toJson())}\n', flush: true);

  /// Newest first. Files that cannot be read are skipped, never fatal.
  Future<List<FlightRecord>> list() async {
    if (!await dir.exists()) return [];
    final out = <FlightRecord>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      final id = e.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), '');
      final hex = File('${dir.path}/$id.hex');
      if (!await hex.exists()) continue;
      try {
        final meta = FlightMeta.fromJson(jsonDecode(await e.readAsString()) as Map<String, dynamic>);
        out.add(FlightRecord(id, meta, hex, e));
      } catch (_) {
        continue;
      }
    }
    out.sort((a, b) => b.meta.startedAtUtc.compareTo(a.meta.startedAtUtc));
    return out;
  }

  /// Bad lines (for example a half-written last line after a crash) are skipped.
  Future<List<GroundFrame>> load(FlightRecord r) async {
    final frames = <GroundFrame>[];
    for (final line in await r.hexFile.readAsLines()) {
      final s = line.trim();
      if (s.isEmpty) continue;
      try {
        frames.add(decodeGroundFrame(hexToBytes(s)));
      } catch (_) {
        continue;
      }
    }
    return frames;
  }

  Future<void> rename(FlightRecord r, String name) async {
    r.meta.name = name;
    await _writeMeta(r);
  }

  Future<void> delete(FlightRecord r) async {
    if (await r.hexFile.exists()) await r.hexFile.delete();
    if (await r.jsonFile.exists()) await r.jsonFile.delete();
  }
}

class FlightWriter {
  final FlightRecord record;
  final RandomAccessFile _file;
  final FlightStore _store;
  int count = 0;
  bool _closed = false;
  FlightWriter._(this.record, this._file, this._store);

  static const int minPackets = 10;

  /// Written and flushed before returning, so a crash loses at most the
  /// packet that was arriving.
  void append(GroundFrame frame) {
    if (_closed) return;
    final raw = frame.raw;
    if (raw == null) return;
    _file.writeStringSync('${bytesToHex(raw)}\n');
    _file.flushSync();
    count++;
    final p = frame.packet;
    if (record.meta.padLat == null && p.has3dFix) {
      record.meta.padLat = p.latDeg;
      record.meta.padLon = p.lonDeg;
      _store._writeMeta(record);
    }
  }

  /// Returns the saved record, or null if the flight was too short and was discarded.
  Future<FlightRecord?> finish() async {
    if (_closed) return null;
    _closed = true;
    _file.closeSync();
    if (count < minPackets) {
      await _store.delete(record);
      return null;
    }
    await _store._writeMeta(record);
    return record;
  }
}

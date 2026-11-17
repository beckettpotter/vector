import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'projection.dart';

/// An imported OpenRocket CSV, copied into the app's own folder so it still
/// works if the original file is moved. Two plain files per projection:
///   `<id>.csv`   the file exactly as exported
///   `<id>.json`  {name, rocketName, sourceFile, importedAtUtc}
class StoredProjection {
  final String id;
  final Projection projection;
  String name;

  /// The rocket profile this simulation belongs to ('' = none).
  String rocketName;
  final String sourceFile;
  final DateTime importedAtUtc;
  StoredProjection(this.id, this.projection,
      {required this.name, this.rocketName = '', this.sourceFile = '', required this.importedAtUtc});

  Map<String, dynamic> toJson() => {
        'name': name,
        'rocketName': rocketName,
        'sourceFile': sourceFile,
        'importedAtUtc': importedAtUtc.toUtc().toIso8601String(),
      };
}

class ProjectionStore {
  final Directory dir;
  ProjectionStore(this.dir);

  File _csv(String id) => File('${dir.path}/$id.csv');
  File _json(String id) => File('${dir.path}/$id.json');

  /// Checks the file first (throws [OpenRocketFormatException] in plain words),
  /// then copies it in. [fileName] is the default name.
  Future<StoredProjection> import(List<int> bytes, String fileName, {DateTime? nowUtc}) async {
    final name = fileName.replaceAll(RegExp(r'\.(csv|txt)$', caseSensitive: false), '');
    final projection = parseOpenRocketCsv(bytes, name: name);
    await dir.create(recursive: true);
    final now = (nowUtc ?? DateTime.now()).toUtc();
    var id = 'sim_${now.microsecondsSinceEpoch}';
    while (_csv(id).existsSync()) {
      id = '${id}_';
    }
    await _csv(id).writeAsBytes(bytes, flush: true);
    final s = StoredProjection(id, projection, name: name, sourceFile: fileName, importedAtUtc: now);
    await save(s);
    return s;
  }

  Future<void> save(StoredProjection s) async {
    s.projection.name = s.name;
    await _json(s.id).writeAsString('${const JsonEncoder.withIndent('  ').convert(s.toJson())}\n', flush: true);
  }

  /// Newest first. A file that no longer parses is skipped, never fatal.
  Future<List<StoredProjection>> list() async {
    if (!await dir.exists()) return [];
    final out = <StoredProjection>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      final id = e.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), '');
      try {
        final j = jsonDecode(await e.readAsString()) as Map<String, dynamic>;
        final name = j['name'] as String? ?? id;
        final p = parseOpenRocketCsv(await _csv(id).readAsBytes(), name: name);
        out.add(StoredProjection(id, p,
            name: name,
            rocketName: j['rocketName'] as String? ?? '',
            sourceFile: j['sourceFile'] as String? ?? '',
            importedAtUtc: DateTime.parse(j['importedAtUtc'] as String).toUtc()));
      } catch (_) {
        continue;
      }
    }
    out.sort((a, b) => b.importedAtUtc.compareTo(a.importedAtUtc));
    return out;
  }

  Future<void> delete(StoredProjection s) async {
    for (final f in [_csv(s.id), _json(s.id)]) {
      if (await f.exists()) await f.delete();
    }
  }
}

/// The imported projections and which one the next flight is compared with.
/// The choice is saved through [saveActive]; the ±1 s launch nudge is not.
class Projections extends ChangeNotifier {
  final ProjectionStore? store;
  final void Function(String id)? saveActive;
  Projections({this.store, this.activeId = '', this.saveActive});

  List<StoredProjection> items = [];
  String activeId;
  String? lastError;

  /// Seconds added to "time since launch" when comparing. Packets are 1 Hz, so
  /// the detected launch can be up to 1 s late.
  double offsetS = 0;

  StoredProjection? get active {
    for (final s in items) {
      if (s.id == activeId) return s;
    }
    return null;
  }

  Future<void> load() async {
    try {
      items = await store?.list() ?? [];
    } catch (_) {
      items = [];
    }
    notifyListeners();
  }

  Future<StoredProjection?> importFile(List<int> bytes, String fileName, {String rocketName = ''}) async {
    final st = store;
    if (st == null) return null;
    try {
      final s = await st.import(bytes, fileName);
      s.rocketName = rocketName;
      await st.save(s);
      items.insert(0, s);
      lastError = null;
      setActive(s.id);
      return s;
    } on OpenRocketFormatException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = 'Could not read or save that file: $e';
    }
    notifyListeners();
    return null;
  }

  void showError(String message) {
    lastError = message;
    notifyListeners();
  }

  void setActive(String id) {
    activeId = id;
    saveActive?.call(id);
    notifyListeners();
  }

  /// Picking a rocket profile also picks the simulation linked to it, if any.
  void rocketChosen(String rocketName) {
    if (rocketName.isEmpty) return;
    for (final s in items) {
      if (s.rocketName == rocketName) {
        setActive(s.id);
        return;
      }
    }
  }

  Future<void> update(StoredProjection s, {String? name, String? rocketName}) async {
    if (name != null && name.trim().isNotEmpty) s.name = name.trim();
    if (rocketName != null) s.rocketName = rocketName;
    await store?.save(s);
    notifyListeners();
  }

  Future<void> remove(StoredProjection s) async {
    await store?.delete(s);
    items.remove(s);
    if (s.id == activeId) setActive('');
    notifyListeners();
  }

  void nudge(double by) {
    offsetS = (offsetS + by).clamp(-1.0, 1.0);
    notifyListeners();
  }
}

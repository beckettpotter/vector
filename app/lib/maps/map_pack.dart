import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Offline map packs. Tiles are downloaded once, on a tap, at home, and the
/// map at the field reads only these files: no network calls at the field.

/// The Hearne Municipal Airport (KLHB) club field. AirNav lists the point as
/// estimated; Beckett can type the exact launch spot instead.
const double hearneLat = 30.8721;
const double hearneLon = -96.6222;

/// Where tiles come from. Small on purpose so another source can be added.
class TileSource {
  final String id;
  final String name;
  final String Function(int z, int x, int y) url;
  final String credit;
  final String imageryAge;
  const TileSource(
      {required this.id, required this.name, required this.url, required this.credit, required this.imageryAge});
}

/// USGS National Map imagery: no account, no key, no billing; US only;
/// visible to about zoom 16. Note the ArcGIS order: z, then y, then x.
final usgsImagery = TileSource(
  id: 'usgs',
  name: 'USGS National Map imagery',
  url: (z, x, y) => 'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/$z/$y/$x',
  credit: 'Map services and data available from U.S. Geological Survey, National Geospatial Program. '
      'USDA, USGS The National Map: Orthoimagery.',
  imageryAge: 'Imagery 2017-2021',
);

const int packMinZoom = 12;
const int packMaxZoom = 16;
const List<double> packRadiiKm = [2, 5, 10];

/// Rough average from real USGS tiles (about 16 KB at zoom 16), for the size
/// estimate shown before downloading.
const int estimatedTileBytes = 20000;

// --- Tile math (Web Mercator, 256 px tiles) ---

int lonToTileX(double lon, int z) {
  final n = 1 << z;
  return ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
}

int latToTileY(double lat, int z) {
  final n = 1 << z;
  final r = lat.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n).floor().clamp(0, n - 1);
}

class TileId {
  final int z, x, y;
  const TileId(this.z, this.x, this.y);
  @override
  bool operator ==(Object other) => other is TileId && other.z == z && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(z, x, y);
  @override
  String toString() => '$z/$x/$y';
}

/// Every tile from [minZoom] to [maxZoom] covering a square of ±[radiusKm]
/// around the centre.
List<TileId> tilesForArea(double lat, double lon, double radiusKm,
    {int minZoom = packMinZoom, int maxZoom = packMaxZoom}) {
  final dLat = radiusKm / 111.32;
  final dLon = radiusKm / (111.32 * math.cos(lat * math.pi / 180));
  final out = <TileId>[];
  for (var z = minZoom; z <= maxZoom; z++) {
    final x0 = lonToTileX(lon - dLon, z), x1 = lonToTileX(lon + dLon, z);
    final y0 = latToTileY(lat + dLat, z), y1 = latToTileY(lat - dLat, z);
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        out.add(TileId(z, x, y));
      }
    }
  }
  return out;
}

// --- Packs on disk ---

/// `<maps>/<id>/pack.json` plus `<maps>/<id>/<z>/<x>/<y>.tile`.
class MapPack {
  final String id;
  String name;
  final double lat, lon, radiusKm;
  final String sourceId;
  int tileCount;
  int bytes;
  bool complete;
  final DateTime createdAtUtc;
  MapPack({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.radiusKm,
    this.sourceId = 'usgs',
    this.tileCount = 0,
    this.bytes = 0,
    this.complete = false,
    required this.createdAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lon': lon,
        'radiusKm': radiusKm,
        'sourceId': sourceId,
        'tileCount': tileCount,
        'bytes': bytes,
        'complete': complete,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      };

  factory MapPack.fromJson(String id, Map<String, dynamic> j) => MapPack(
        id: id,
        name: j['name'] as String? ?? id,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        radiusKm: (j['radiusKm'] as num).toDouble(),
        sourceId: j['sourceId'] as String? ?? 'usgs',
        tileCount: (j['tileCount'] as num?)?.toInt() ?? 0,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        complete: j['complete'] as bool? ?? false,
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String).toUtc(),
      );

  /// Is this point inside the downloaded square?
  bool covers(double plat, double plon) {
    final dLat = radiusKm / 111.32;
    final dLon = radiusKm / (111.32 * math.cos(lat * math.pi / 180));
    return (plat - lat).abs() <= dLat && (plon - lon).abs() <= dLon;
  }
}

/// Folder-safe id from a field name: one pack per field.
String packIdFor(String name) {
  final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  return s.isEmpty ? 'field' : s;
}

class MapPackStore {
  final Directory dir;
  MapPackStore(this.dir);

  Directory packDir(String id) => Directory('${dir.path}/$id');
  File tileFile(String id, int z, int x, int y) => File('${dir.path}/$id/$z/$x/$y.tile');

  Future<void> save(MapPack p) async {
    await packDir(p.id).create(recursive: true);
    await File('${packDir(p.id).path}/pack.json')
        .writeAsString('${const JsonEncoder.withIndent('  ').convert(p.toJson())}\n', flush: true);
  }

  /// Packs that cannot be read are skipped, never fatal.
  Future<List<MapPack>> list() async {
    if (!await dir.exists()) return [];
    final out = <MapPack>[];
    await for (final e in dir.list()) {
      if (e is! Directory) continue;
      final id = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      try {
        final j = jsonDecode(await File('${e.path}/pack.json').readAsString()) as Map<String, dynamic>;
        out.add(MapPack.fromJson(id, j));
      } catch (_) {
        continue;
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<void> delete(MapPack p) async {
    final d = packDir(p.id);
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// The stored pack whose area contains this point, if any.
  Future<MapPack?> covering(double lat, double lon) async {
    for (final p in await list()) {
      if (p.covers(lat, lon)) return p;
    }
    return null;
  }
}

// --- Downloading (only ever from a tap) ---

class DownloadProgress {
  final int done, total, failed, bytes;
  const DownloadProgress(this.done, this.total, this.failed, this.bytes);
}

class DownloadCancelled implements Exception {}

class DownloadFailed implements Exception {
  final String message;
  DownloadFailed(this.message);
  @override
  String toString() => message;
}

/// Polite to the server: at most [parallel] requests at once, a pause between
/// batches, a User-Agent naming Vector, tiles already stored are not fetched
/// again, and it stops after repeated errors.
class MapDownloader {
  final http.Client client;
  final MapPackStore store;
  final TileSource source;
  final int parallel;
  final Duration pause;
  final int maxConsecutiveErrors;
  MapDownloader(this.client, this.store,
      {TileSource? source,
      this.parallel = 3,
      this.pause = const Duration(milliseconds: 250),
      this.maxConsecutiveErrors = 8})
      : source = source ?? usgsImagery;

  static const userAgent = 'Vector rocket tracker (offline map pack for one launch field; '
      'https://github.com/beckettpotter/vector)';

  bool _cancel = false;
  void cancel() => _cancel = true;

  Future<MapPack> download(MapPack pack, {void Function(DownloadProgress p)? onProgress}) async {
    _cancel = false;
    final tiles = tilesForArea(pack.lat, pack.lon, pack.radiusKm);
    pack
      ..tileCount = tiles.length
      ..complete = false;
    await store.save(pack);
    var done = 0, failed = 0, bytes = 0, errorsInARow = 0;
    for (var i = 0; i < tiles.length; i += parallel) {
      if (_cancel) {
        await _finish(pack, bytes, false);
        throw DownloadCancelled();
      }
      final batch = tiles.sublist(i, math.min(i + parallel, tiles.length));
      var fetched = false;
      final results = await Future.wait(batch.map((t) async {
        final f = store.tileFile(pack.id, t.z, t.x, t.y);
        if (await f.exists() && await f.length() > 0) return (await f.length(), true, false);
        fetched = true;
        try {
          final r = await client
              .get(Uri.parse(source.url(t.z, t.x, t.y)), headers: {'User-Agent': userAgent})
              .timeout(const Duration(seconds: 30));
          if (r.statusCode != 200 || r.bodyBytes.isEmpty) return (0, false, true);
          await f.parent.create(recursive: true);
          await f.writeAsBytes(r.bodyBytes, flush: true);
          return (r.bodyBytes.length, true, true);
        } catch (_) {
          return (0, false, true);
        }
      }));
      for (final (size, ok, _) in results) {
        done++;
        if (ok) {
          bytes += size;
          errorsInARow = 0;
        } else {
          failed++;
          errorsInARow++;
        }
      }
      onProgress?.call(DownloadProgress(done, tiles.length, failed, bytes));
      if (errorsInARow >= maxConsecutiveErrors) {
        await _finish(pack, bytes, false);
        throw DownloadFailed('The map server stopped answering ($errorsInARow tiles in a row failed). '
            'Tiles already saved are kept; try again later to fill in the rest.');
      }
      if (fetched && i + parallel < tiles.length) await Future.delayed(pause);
    }
    return _finish(pack, bytes, failed == 0);
  }

  Future<MapPack> _finish(MapPack pack, int bytes, bool complete) async {
    pack
      ..bytes = bytes
      ..complete = complete;
    await store.save(pack);
    return pack;
  }
}

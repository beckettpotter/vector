import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'map_pack.dart';

/// Stored map packs and the one download that may be running.
class Maps extends ChangeNotifier {
  final MapPackStore? store;

  /// Only used when the user taps Download; the map itself never uses it.
  final http.Client Function() newClient;

  /// Pause between batches of tile requests (shorter only in tests).
  final Duration pause;
  Maps({this.store, http.Client Function()? newClient, this.pause = const Duration(milliseconds: 250)})
      : newClient = newClient ?? http.Client.new;

  List<MapPack> packs = [];
  MapDownloader? _running;
  DownloadProgress? progress;
  String? message;

  bool get downloading => _running != null;

  Future<void> load() async {
    try {
      packs = await store?.list() ?? [];
    } catch (_) {
      packs = [];
    }
    notifyListeners();
  }

  /// A stored pack whose area contains this point.
  MapPack? packFor(double lat, double lon) {
    MapPack? partial;
    for (final p in packs) {
      if (!p.covers(lat, lon)) continue;
      if (p.complete) return p;
      partial ??= p;
    }
    return partial;
  }

  Future<void> download(String name, double lat, double lon, double radiusKm) async {
    final st = store;
    if (st == null || downloading) return;
    final pack = MapPack(
        id: packIdFor(name), name: name, lat: lat, lon: lon, radiusKm: radiusKm, createdAtUtc: DateTime.now().toUtc());
    // One pack per field: a new area for the same field replaces the old one.
    final old = packs.where((p) => p.id == pack.id).toList();
    for (final p in old) {
      if (p.lat != lat || p.lon != lon || p.radiusKm != radiusKm) await st.delete(p);
      packs.remove(p);
    }
    final client = newClient();
    final d = _running = MapDownloader(client, st, pause: pause);
    message = null;
    progress = DownloadProgress(0, tilesForArea(lat, lon, radiusKm).length, 0, 0);
    packs.add(pack);
    notifyListeners();
    try {
      await d.download(pack, onProgress: (p) {
        progress = p;
        notifyListeners();
      });
      message = pack.complete
          ? 'Map saved: ${pack.tileCount} tiles, ${formatMb(pack.bytes)}. It works offline now.'
          : 'Map saved with ${progress!.failed} tiles missing. Download again to fill them in.';
    } on DownloadCancelled {
      message = 'Download cancelled. Tiles already saved are kept.';
    } on DownloadFailed catch (e) {
      message = e.message;
    } finally {
      client.close();
      _running = null;
      notifyListeners();
    }
  }

  void cancel() => _running?.cancel();

  Future<void> delete(MapPack p) async {
    await store?.delete(p);
    packs.remove(p);
    notifyListeners();
  }
}

String formatMb(int bytes) => '${(bytes / 1e6).toStringAsFixed(bytes < 1e7 ? 1 : 0)} MB';

/// Reads tiles from the pack's files only. A tile that was not downloaded is
/// drawn as nothing (transparent).
class PackTileProvider extends TileProvider {
  final MapPackStore store;
  final MapPack pack;
  PackTileProvider(this.store, this.pack);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final f = store.tileFile(pack.id, coordinates.z, coordinates.x, coordinates.y);
    return f.existsSync() ? FileImage(f) : MemoryImage(transparentPng);
  }
}

/// A 1x1 transparent PNG.
final Uint8List transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x60,
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0xA5, 0xF6, 0x45, 0x40, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Default folder for packs, next to the flights folder.
Directory mapsFolderBeside(Directory flights) => Directory('${flights.parent.path}${Platform.pathSeparator}maps');

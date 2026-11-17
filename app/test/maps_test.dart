import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/maps/map_pack.dart';
import 'package:vector/maps/maps.dart';
import 'package:vector/screens/map_pack_screen.dart';
import 'package:vector/screens/track_screen.dart';
import 'package:vector/settings.dart';
import 'package:vector/theme.dart';

import 'helpers.dart';

/// A pretend tile server that counts requests and how many run at once.
class FakeServer {
  int requests = 0, inFlight = 0, maxInFlight = 0;
  final userAgents = <String?>{};
  bool Function(Uri u) fails = (_) => false;

  http.Client client() => MockClient((req) async {
        requests++;
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        userAgents.add(req.headers['User-Agent']);
        await Future.delayed(const Duration(milliseconds: 1));
        inFlight--;
        if (fails(req.url)) return http.Response('busy', 503);
        return http.Response.bytes(transparentPng, 200);
      });
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('vector_maps_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('tile math: known points', () {
    // Checked against a real USGS request on 2026-11-17 (the Hearne runway).
    expect(lonToTileX(hearneLon, 16), 15178);
    expect(latToTileY(hearneLat, 16), 26854);
    expect(lonToTileX(0, 1), 1);
    expect(latToTileY(0, 1), 1);
    expect(lonToTileX(-180, 3), 0);
    expect(lonToTileX(180, 3), 7); // the last column, never off the edge
    expect(latToTileY(85.0511, 4), 0);
  });

  test('tile counts for each radius, zoom 12 to 16', () {
    final counts = [for (final r in packRadiiKm) tilesForArea(hearneLat, hearneLon, r).length];
    expect(counts[0], lessThan(counts[1]));
    expect(counts[1], lessThan(counts[2]));
    final t = tilesForArea(hearneLat, hearneLon, 5);
    expect(t.map((e) => e.z).toSet(), {12, 13, 14, 15, 16});
    expect(t.toSet().length, t.length); // no duplicates
    expect(t, contains(const TileId(16, 15178, 26854)));
    // A 10 km pack is a couple of thousand tiles, tens of MB: shown before downloading.
    expect(counts[2], inInclusiveRange(1000, 3000));
  });

  test('download: polite, User-Agent, saved to disk, never fetches a stored tile twice', () async {
    final server = FakeServer();
    final store = MapPackStore(Directory('${tmp.path}/maps'));
    final maps = Maps(store: store, newClient: server.client, pause: Duration.zero);
    await maps.download('Hearne airport', hearneLat, hearneLon, 2);
    final n = tilesForArea(hearneLat, hearneLon, 2).length;
    expect(server.requests, n);
    expect(server.maxInFlight, lessThanOrEqualTo(3));
    expect(server.userAgents.single, contains('Vector'));
    final pack = maps.packs.single;
    expect(pack.complete, isTrue);
    expect(pack.tileCount, n);
    expect(store.tileFile(pack.id, 16, 15178, 26854).existsSync(), isTrue);
    expect(maps.message, contains('works offline'));

    await maps.download('Hearne airport', hearneLat, hearneLon, 2); // same field again
    expect(server.requests, n);

    final again = Maps(store: store);
    await again.load();
    expect(again.packFor(hearneLat, hearneLon)!.name, 'Hearne airport');
    expect(again.packFor(32.99, -106.97), isNull); // Spaceport America is not in this pack
    await again.delete(again.packs.single);
    expect(store.packDir(pack.id).existsSync(), isFalse);
    expect(await store.list(), isEmpty);
  });

  test('download stops after repeated errors and keeps what it saved', () async {
    final server = FakeServer()..fails = (u) => u.path.contains('/tile/16/');
    final maps = Maps(store: MapPackStore(Directory('${tmp.path}/maps')), newClient: server.client, pause: Duration.zero);
    await maps.download('Hearne airport', hearneLat, hearneLon, 2);
    expect(maps.message, contains('stopped answering'));
    final pack = maps.packs.single;
    expect(pack.complete, isFalse);
    expect(server.requests, lessThan(tilesForArea(hearneLat, hearneLon, 2).length));
  });

  test('cancel stops the download', () async {
    final server = FakeServer();
    final maps = Maps(store: MapPackStore(Directory('${tmp.path}/maps')), newClient: server.client, pause: Duration.zero);
    final running = maps.download('Hearne airport', hearneLat, hearneLon, 10);
    await Future.delayed(const Duration(milliseconds: 20));
    maps.cancel();
    await running;
    expect(maps.message, contains('cancelled'));
    expect(server.requests, lessThan(tilesForArea(hearneLat, hearneLon, 10).length));
  });

  Future<void> pumpTrack(WidgetTester tester, LinkController link, Maps maps, AppSettings settings) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await tester.pumpWidget(MaterialApp(
        theme: buildVectorTheme(),
        home: Scaffold(body: TrackView(link: link, maps: maps, settings: settings))));
  }

  testWidgets('no map for the area: the plot, one calm line and a download button', (tester) async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final maps = Maps(store: MapPackStore(Directory('${tmp.path}/maps')));
    for (final f in sampleFlight()) {
      link.handleFrame(f);
    }
    await pumpTrack(tester, link, maps, AppSettings());
    expect(find.text('No map downloaded for this area. Showing the plot.'), findsOneWidget);
    expect(find.byKey(const Key('downloadForField')), findsOneWidget);
    expect(find.byType(TrackMap), findsNothing);
    link.dispose();
  });

  testWidgets('with a map for the area: the map with the USGS credit, and no network at all', (tester) async {
    final server = FakeServer();
    final store = MapPackStore(Directory('${tmp.path}/maps'));
    final maps = Maps(store: store, newClient: server.client, pause: Duration.zero);
    // The sample flight's pad is near Spaceport America.
    final pad = sampleFlight().firstWhere((f) => f.packet.has3dFix).packet;
    await tester.runAsync(() => maps.download('Test field', pad.latDeg, pad.lonDeg, 2));
    final downloaded = server.requests;

    final link = LinkController(nowMs: () => 0, tick: false);
    for (final f in sampleFlight()) {
      link.handleFrame(f);
    }
    final settings = AppSettings();
    await pumpTrack(tester, link, maps, settings);
    await tester.pump();
    expect(find.byType(TrackMap), findsOneWidget);
    expect(find.textContaining('U.S. Geological Survey'), findsOneWidget);
    expect(find.textContaining('Imagery 2017-2021'), findsOneWidget);
    expect(find.textContaining('No map downloaded'), findsNothing);
    expect(server.requests, downloaded); // showing the map made no network request

    settings.showMap = false; // the toggle goes back to the plot
    await tester.pump();
    expect(find.byType(TrackMap), findsNothing);
    link.dispose();
  });

  testWidgets('map pack screen: Hearne by default, size estimate, honesty note, nothing downloaded until tapped',
      (tester) async {
    final server = FakeServer();
    final maps = Maps(store: MapPackStore(Directory('${tmp.path}/maps')), newClient: server.client);
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    await tester.pumpWidget(MaterialApp(theme: buildVectorTheme(), home: MapPackScreen(maps: maps)));
    expect(find.text('Hearne airport'), findsWidgets);
    final n = tilesForArea(30.8721, -96.6222, 5).length;
    expect(find.textContaining('$n tiles (zoom 12 to 16)'), findsOneWidget);
    expect(find.text(mapHonestyNote), findsOneWidget);
    await tester.tap(find.text('10 km'));
    await tester.pump();
    expect(find.textContaining('${tilesForArea(30.8721, -96.6222, 10).length} tiles'), findsOneWidget);
    expect(server.requests, 0);
  });
}

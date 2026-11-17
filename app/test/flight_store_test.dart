import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/checklist.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/protocol/flight_stats.dart';
import 'package:vector/protocol/packet.dart';
import 'package:vector/services.dart';
import 'package:vector/settings.dart';
import 'package:vector/storage/flight_store.dart';
import 'package:vector/storage/recorder.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  late FlightStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vector_store_');
    store = FlightStore(Directory('${tmp.path}/flights'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  final expected = (jsonDecode(File('../protocol/expected_stats.json').readAsStringSync())
      as Map<String, dynamic>)['stats'] as Map<String, dynamic>;

  void expectSampleStats(FlightStats s) {
    expect(s.apogeeM, closeTo(expected['apogee_m'], 0.1));
    expect(s.timeToApogeeS, closeTo(expected['time_to_apogee_s'], 0.1));
    expect(s.maxVerticalSpeedMs, closeTo(expected['max_vertical_speed_ms'], 0.1));
    expect(s.descentRateMs, closeTo(expected['descent_rate_ms'], 0.1));
    expect(s.flightTimeS, closeTo(expected['flight_time_s'], 0.1));
    expect(s.landingDistanceM, closeTo(expected['landing_distance_m'], 0.1));
    expect(s.packetCount, expected['packet_count']);
  }

  test('write, list, load the sample flight; hex file is byte-identical', () async {
    final w = await store.startFlight(
        FlightMeta(name: 'Sample', rocketId: 1, startedAtUtc: DateTime.utc(2026, 12, 12, 17, 30, 5)));
    for (final f in sampleFlight()) {
      w.append(f);
    }
    expect(await w.finish(), isNotNull);
    final list = await store.list();
    expect(list.length, 1);
    expect(list.first.id, 'flight_1_20261212_173005');
    expect(list.first.meta.name, 'Sample');
    expect(list.first.meta.padLat, closeTo(32.99, 1e-9));
    expect(list.first.hexFile.readAsStringSync(), File('../protocol/sample_flight.hex').readAsStringSync());
    final frames = await store.load(list.first);
    expectSampleStats(computeStats(frames.map((f) => f.packet).toList()));
  });

  test('list is newest first; rename and delete work', () async {
    for (final h in [10, 12, 11]) {
      final w = await store.startFlight(FlightMeta(name: 'F$h', rocketId: 1, startedAtUtc: DateTime.utc(2026, 1, 1, h)));
      for (final f in sampleFlight().take(12)) {
        w.append(f);
      }
      await w.finish();
    }
    var list = await store.list();
    expect(list.map((r) => r.meta.name), ['F12', 'F11', 'F10']);
    await store.rename(list[1], 'Renamed');
    list = await store.list();
    expect(list[1].meta.name, 'Renamed');
    await store.delete(list[0]);
    list = await store.list();
    expect(list.map((r) => r.meta.name), ['Renamed', 'F10']);
  });

  test('a flight with fewer than 10 packets is discarded', () async {
    final w = await store.startFlight(FlightMeta(name: 'short', rocketId: 1, startedAtUtc: DateTime.utc(2026)));
    for (final f in sampleFlight().take(9)) {
      w.append(f);
    }
    expect(await w.finish(), isNull);
    expect(await store.list(), isEmpty);
    expect(store.dir.listSync(), isEmpty);
  });

  test('crash safety: every appended frame is on disk before the next one', () async {
    final w = await store.startFlight(FlightMeta(name: 'c', rocketId: 1, startedAtUtc: DateTime.utc(2026)));
    final frames = sampleFlight();
    for (var i = 0; i < 20; i++) {
      w.append(frames[i]);
      final onDisk = w.record.hexFile.readAsLinesSync();
      expect(onDisk.length, i + 1);
      expect(onDisk.last, bytesToHex(frames[i].raw!));
    }
    // A half-written last line (crash mid-write) is skipped on load.
    w.record.hexFile.writeAsStringSync('0101abc', mode: FileMode.append);
    final list = await store.list();
    expect((await store.load(list.first)).length, 20);
  });

  group('recorder', () {
    late LinkController link;
    late Recorder rec;
    setUp(() {
      link = LinkController(nowMs: () => 0, tick: false);
      rec = Recorder(store: store, link: link, clockUtc: () => DateTime.utc(2026, 12, 12, 18));
    });
    tearDown(() {
      rec.dispose();
      link.dispose();
    });

    test('records the whole sample flight, including the pad period', () async {
      for (final f in sampleFlight()) {
        link.handleFrame(f);
      }
      await rec.flush();
      final list = await store.list();
      expect(list.length, 1);
      final frames = await store.load(list.first);
      expect(frames.length, 178);
      expectSampleStats(computeStats(frames.map((f) => f.packet).toList()));
      expect(list.first.meta.name, 'Rocket 1, 2026-12-12 18:00 UTC');
    });

    test('an idle tracker on the pad is not recorded, and only 30 pad packets are kept', () async {
      for (var i = 0; i < 50; i++) {
        link.handleFrame(makeFrame(seq: i, timeMs: 1000 * i));
      }
      await rec.flush();
      expect(await store.list(), isEmpty);
      for (var i = 50; i < 60; i++) {
        link.handleFrame(makeFrame(seq: i, timeMs: 1000 * i, phase: Phase.boost));
      }
      await rec.flush();
      final frames = await store.load((await store.list()).single);
      expect(frames.length, 40);
      expect(frames.first.packet.seq, 20);
    });

    test('ends 15 s after landing; a new session starts a new file', () async {
      var seq = 0;
      void send(Phase ph, int n, {int rocketId = 1}) {
        for (var i = 0; i < n; i++) {
          link.handleFrame(makeFrame(rocketId: rocketId, seq: seq, timeMs: 1000 * seq, phase: ph));
          seq++;
        }
      }
      send(Phase.boost, 5);
      send(Phase.descent, 10);
      send(Phase.landed, 20);
      await Future.delayed(Duration.zero);
      await rec.flush();
      var frames = await store.load((await store.list()).single);
      expect(frames.length, 5 + 10 + 16); // landed packets at +0..+15 s
      send(Phase.coast, 12, rocketId: 2); // new session (different rocket)
      await rec.flush();
      expect((await store.list()).length, 2);
    });

    test('short flights are discarded', () async {
      for (var i = 0; i < 5; i++) {
        link.handleFrame(makeFrame(seq: i, timeMs: 1000 * i, phase: Phase.boost));
      }
      await rec.flush();
      expect(await store.list(), isEmpty);
    });
  });

  test('the checklist as ticked before launch is saved with the flight', () async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final checklist = Checklist();
    final rec = Recorder(store: store, link: link, fillMeta: checklist.fillFlight);
    final s = Services(link: link, settings: AppSettings(), store: store, recorder: rec, checklist: checklist);
    checklist.edit(checklist.items[1], note: 'took 40 s');
    checklist.launchNotes = 'Calm, sunny';
    var ticked = false;
    for (final f in sampleFlight()) {
      link.handleFrame(f);
      if (!ticked && f.packet.phase == Phase.pad) {
        checklist.toggle('armed');
        checklist.toggle('gps');
        ticked = true;
      }
    }
    await rec.flush();
    expect(checklist.ticked, isEmpty); // cleared at launch
    final record = (await store.list()).single;
    final saved = jsonDecode(record.jsonFile.readAsStringSync()) as Map<String, dynamic>;
    expect(saved['launchNotes'], 'Calm, sunny');
    final items = record.meta.checklist!;
    expect(items.map((c) => c.ticked), [true, true, false, false, false]);
    expect(items[1].text, 'GPS fix on the pad');
    expect(items[1].note, 'took 40 s');
    rec.dispose();
    link.dispose();
    expect(s.checklist, same(checklist));
  });

  test('flights saved before checklists existed still load', () async {
    final w = await store.startFlight(FlightMeta(name: 'old', rocketId: 1, startedAtUtc: DateTime.utc(2026)));
    for (final f in sampleFlight().take(20)) {
      w.append(f);
    }
    await w.finish();
    final r = (await store.list()).single;
    expect(r.meta.checklist, isNull);
    expect(jsonDecode(r.jsonFile.readAsStringSync()), isNot(contains('checklist')));
  });
}

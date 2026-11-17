import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/checklist.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/link/replay_link.dart';
import 'package:vector/openrocket/projection.dart';
import 'package:vector/openrocket/projection_store.dart';
import 'package:vector/protocol/packet.dart';
import 'package:vector/screens/flight_detail_screen.dart';
import 'package:vector/screens/hud_screen.dart';
import 'package:vector/screens/projection_widgets.dart';
import 'package:vector/services.dart';
import 'package:vector/settings.dart';
import 'package:vector/storage/flight_store.dart';
import 'package:vector/storage/recorder.dart';
import 'package:vector/theme.dart';

import 'helpers.dart';

final realBytes = File('test/fixtures/openrocket_real.csv').readAsBytesSync();

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('vector_proj_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> pumpBody(WidgetTester tester, Widget body, {Size size = const Size(1100, 3000)}) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(MaterialApp(theme: buildVectorTheme(), home: Scaffold(body: body)));
  }

  test('import copies the file in; list, link to a rocket and delete', () async {
    final store = ProjectionStore(Directory('${tmp.path}/projections'));
    String? saved;
    final ps = Projections(store: store, saveActive: (id) => saved = id);
    final s = await ps.importFile(realBytes, 'test.csv', rocketName: 'Journey 75');
    expect(s!.name, 'test');
    expect(ps.active, same(s));
    expect(saved, s.id);
    expect(File('${store.dir.path}/${s.id}.csv').readAsBytesSync(), realBytes); // exact copy

    final again = Projections(store: store, activeId: s.id);
    await again.load();
    expect(again.active!.projection.apogeeM, closeTo(852.6, 0.05));
    expect(again.active!.rocketName, 'Journey 75');
    again.setActive('');
    again.rocketChosen('Journey 75');
    expect(again.active!.id, s.id);

    expect(await ps.importFile(utf8.encode('hello'), 'notes.csv'), isNull);
    expect(ps.lastError, contains('OpenRocket'));

    await ps.remove(s);
    expect(ps.active, isNull);
    expect(await store.list(), isEmpty);
  });

  testWidgets('Pre-flight card: import, the numbers, no-recovery and stability notes, waiver ceiling',
      (tester) async {
    final ps = Projections(store: ProjectionStore(Directory('${tmp.path}/p')));
    final settings = AppSettings();
    var picks = 0;
    await pumpBody(
        tester,
        ListenableBuilder(
          listenable: Listenable.merge([ps, settings]),
          builder: (_, _) => ListView(children: [
            ProjectionCard(projections: ps, settings: settings, pickFile: () async {
              picks++;
              return (realBytes, 'test.csv');
            }),
          ]),
        ));
    expect(find.textContaining('No simulation imported yet'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('importProjection')));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(picks, 1);
    expect(find.text('852.6 m'), findsOneWidget);
    expect(find.text('2797 ft'), findsOneWidget);
    expect(find.text('16.8 g'), findsOneWidget);
    expect(find.text('-0.41 cal'), findsOneWidget);
    expect(find.textContaining('unstable or marginal'), findsOneWidget);
    expect(find.text(noRecoveryLabelText), findsNWidgets(2)); // descent rate and flight time, in grey
    expect(find.textContaining('add the recovery device'), findsOneWidget);
    expect(find.textContaining('OpenRocket warning: No recovery device'), findsOneWidget);
    expect(find.textContaining('waiver ceiling of'), findsNothing); // blank: says nothing

    await tester.enterText(find.byKey(const Key('waiverCeiling')), '2500');
    await tester.pump();
    expect(find.text('Projected apogee 2797 ft is above the waiver ceiling of 2500 ft.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('waiverCeiling')), '3000');
    await tester.pump();
    expect(find.textContaining('waiver ceiling of'), findsNothing);
  });

  testWidgets('HUD: projection before launch, then predicted now, difference and chip', (tester) async {
    final ps = Projections(store: ProjectionStore(Directory('${tmp.path}/p')));
    await tester.runAsync(() => ps.importFile(realBytes, 'test.csv'));
    final link = LinkController(nowMs: () => 0, tick: false);
    await pumpBody(tester, ListView(children: [HudPanel(link: link, settings: AppSettings(), projections: ps)]));
    final frames = sampleFlight();
    final firstBoost = frames.indexWhere((f) => f.packet.phase == Phase.boost);
    for (final f in frames.take(firstBoost)) {
      link.handleFrame(f);
    }
    await tester.pump();
    expect(find.textContaining('The comparison starts at launch'), findsOneWidget);

    for (final f in frames.skip(firstBoost).take(5)) {
      link.handleFrame(f);
    }
    await tester.pump();
    expect(find.text('PREDICTED NOW'), findsOneWidget);
    expect(find.byKey(const Key('aheadChip')), findsOneWidget);
    expect(find.text('4.0 s after launch'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nudgePlus')));
    await tester.pump();
    expect(find.text('4.5 s after launch'), findsOneWidget);
    link.dispose();
  });

  test('the projection in use is saved inside the flight file, and Replay uses it', () async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final store = FlightStore(Directory('${tmp.path}/flights'));
    final ps = Projections(store: ProjectionStore(Directory('${tmp.path}/p')));
    await ps.importFile(realBytes, 'test.csv');
    ps.nudge(0.5);
    final checklist = Checklist();
    final rec = Recorder(
        store: store,
        link: link,
        fillMeta: (m) {
          checklist.fillFlight(m);
          m.projection = ps.active?.projection;
          m.projectionOffsetS = ps.offsetS;
        });
    Services(link: link, settings: AppSettings(), store: store, recorder: rec, checklist: checklist, projections: ps);
    for (final f in sampleFlight()) {
      link.handleFrame(f);
    }
    await rec.flush();
    await ps.remove(ps.active!); // deleting the import does not lose the comparison
    final r = (await store.list()).single;
    expect(r.meta.projection!.apogeeM, closeTo(852.6, 0.05));
    expect(r.meta.projectionOffsetS, 0.5);
    final json = jsonDecode(r.jsonFile.readAsStringSync()) as Map<String, dynamic>;
    expect((json['projection'] as Map)['name'], 'test');

    final replay = ReplayLink(sampleFlight(), name: 'x', projection: r.meta.projection, projectionOffsetS: 0.5);
    await link.useSource(replay);
    final (p, offset) = projectionInUse(link, Projections());
    expect(p!.name, 'test');
    expect(offset, 0.5);
    rec.dispose();
    link.dispose();
  });

  testWidgets('flight detail: summary, table with no-recovery rows, RMS and charts', (tester) async {
    final store = FlightStore(Directory('${tmp.path}/flights'));
    final proj = parseOpenRocketCsv(realBytes, name: 'Journey 75 sim');
    late FlightRecord record;
    await tester.runAsync(() async {
      final w = await store.startFlight(
          FlightMeta(name: 'Test flight', rocketId: 1, startedAtUtc: DateTime.utc(2026, 12, 12), projection: proj));
      for (final f in sampleFlight()) {
        w.append(f);
      }
      record = (await w.finish())!;
    });
    await tester.binding.setSurfaceSize(const Size(1100, 4000));
    await tester.pumpWidget(MaterialApp(
        theme: buildVectorTheme(),
        home: FlightDetailScreen(store: store, record: record, settings: AppSettings())));
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.scrollUntilVisible(find.text('Real versus predicted'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Real versus predicted'), findsOneWidget);
    expect(find.text('Flew 11.3% higher than predicted (948.5 m against 852.6 m).'), findsOneWidget);
    expect(find.text('Reached apogee 2.2 s later than predicted.'), findsOneWidget);
    expect(find.text(noRecoveryLabelText), findsNWidgets(3)); // descent, flight time, landing distance
    await tester.scrollUntilVisible(find.text('Altitude (m), real versus predicted'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('RMS'), findsWidgets);
  });
}

const noRecoveryLabelText = 'Simulation has no recovery device';

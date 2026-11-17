import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/checklist.dart';
import 'package:vector/screens/preflight_screen.dart';
import 'package:vector/settings.dart';
import 'package:vector/storage/recorder.dart';
import 'package:vector/theme.dart';
import 'package:vector/time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Chicago time follows daylight saving', () {
    // Winter: CST, UTC-6.
    expect(formatClock(DateTime.utc(2026, 12, 12, 18), chicagoZone), '2026-12-12 12:00 Chicago time');
    // Summer: CDT, UTC-5.
    expect(formatClock(DateTime.utc(2026, 7, 1, 18), chicagoZone), '2026-07-01 13:00 Chicago time');
    // The spring change on 2026-03-08: 2:00 local jumps to 3:00.
    expect(formatClock(DateTime.utc(2026, 3, 8, 7, 59), chicagoZone), '2026-03-08 01:59 Chicago time');
    expect(formatClock(DateTime.utc(2026, 3, 8, 8, 0), chicagoZone), '2026-03-08 03:00 Chicago time');
    // The autumn change on 2026-11-01: 1:00 to 2:00 happens twice.
    expect(formatClock(DateTime.utc(2026, 11, 1, 6, 30), chicagoZone), '2026-11-01 01:30 Chicago time');
    expect(formatClock(DateTime.utc(2026, 11, 1, 7, 30), chicagoZone), '2026-11-01 01:30 Chicago time');
  });

  test('other zones, labels and a bad zone name', () {
    expect(formatClock(DateTime.utc(2026, 12, 12, 18), 'America/Denver'), '2026-12-12 11:00 Denver time');
    expect(zoneLabel('America/Argentina/Buenos_Aires'), 'Buenos Aires time');
    expect(formatClock(DateTime.utc(2026, 12, 12, 18), 'Not/AZone'), '2026-12-12 12:00 Chicago time');
    expect(allZoneNames(), contains(chicagoZone));
    expect(formatClock(DateTime.utc(2026, 12, 12, 18), deviceZoneSetting), contains("this device's time"));
  });

  test('the setting defaults to Chicago, is saved, and never changes stored UTC names', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await AppSettings.load();
    expect(a.timeZone, chicagoZone);
    expect(a.formatTime(DateTime.utc(2026, 12, 12, 18)), '2026-12-12 12:00 Chicago time');
    a.timeZone = 'Europe/London';
    await Future.delayed(Duration.zero);
    final b = await AppSettings.load();
    expect(b.formatTime(DateTime.utc(2026, 12, 12, 18)), '2026-12-12 18:00 London time');

    // "From my location" uses the device zone until a location zone is known.
    b.timeZone = locationZoneSetting;
    expect(b.displayZone, deviceZoneSetting);
    b.locationTimeZone = 'America/Denver';
    expect(b.formatTime(DateTime.utc(2026, 12, 12, 18)), '2026-12-12 11:00 Denver time');

    expect(defaultFlightName(1, DateTime.utc(2026, 12, 12, 18)), 'Rocket 1, 2026-12-12 18:00 UTC');
    expect(defaultFlightName(1, DateTime.utc(2026, 12, 12, 18), formatTime: AppSettings().formatTime),
        'Rocket 1, 2026-12-12 12:00 Chicago time');
  });

  test('a broken saved zone falls back to Chicago', () async {
    SharedPreferences.setMockInitialValues({'timeZone': 'Mars/Olympus'});
    final s = await AppSettings.load();
    expect(s.displayZone, chicagoZone);
  });

  testWidgets('pick a zone from the list', (tester) async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final settings = AppSettings();
    await tester.binding.setSurfaceSize(const Size(1000, 3000));
    await tester.pumpWidget(MaterialApp(
      theme: buildVectorTheme(),
      home: Scaffold(body: PreflightView(link: link, settings: settings, checklist: Checklist())),
    ));
    expect(find.textContaining('Chicago time (default)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeZone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zone_pick')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('zoneSearch')), 'denver');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denver time'));
    await tester.pumpAndSettle();
    expect(settings.timeZone, 'America/Denver');
    expect(find.textContaining('Denver time.'), findsOneWidget);
    link.dispose();
  });
}

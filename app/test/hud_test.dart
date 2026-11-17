import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/protocol/packet.dart';
import 'package:vector/screens/hud_screen.dart';
import 'package:vector/settings.dart';
import 'package:vector/theme.dart';

import 'helpers.dart';

void main() {
  late int now;
  late LinkController link;
  late AppSettings settings;

  setUp(() {
    now = 0;
    link = LinkController(nowMs: () => now, tick: false);
    settings = AppSettings();
  });
  tearDown(() => link.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(MaterialApp(
      theme: buildVectorTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([link, settings]),
          builder: (context, _) => ListView(children: [
            StaleBanner(link: link, settings: settings),
            HudPanel(link: link, settings: settings),
          ]),
        ),
      ),
    ));
  }

  testWidgets('live values appear', (tester) async {
    await pump(tester);
    expect(find.text('Waiting for a rocket'), findsOneWidget);
    link.handleFrame(makeFrame(baroAltCm: 12345, vspeedCms: -650, phase: Phase.descent, rssi: -77, snr: 4,
        batteryMv: 3980));
    await tester.pump();
    expect(find.text('123.5 m'), findsNWidgets(2)); // altitude and max altitude
    expect(find.text('405 ft'), findsNWidgets(2));
    expect(find.text('-6.5 m/s'), findsOneWidget);
    expect(find.text('DESCENT'), findsOneWidget);
    expect(find.text('3.98 V'), findsOneWidget);
    expect(find.text('-77 dBm'), findsOneWidget);
    expect(find.text('SNR 4 dB'), findsOneWidget);
    expect(find.text('3D fix'), findsOneWidget);
    expect(find.text('last known'), findsNothing);
    expect(find.textContaining('STALE'), findsNothing);
  });

  testWidgets('NO GPS FIX with fix type 0', (tester) async {
    await pump(tester);
    link.handleFrame(makeFrame(fixType: 0, sats: 0, phase: Phase.boost));
    await tester.pump();
    expect(find.text('NO GPS FIX'), findsOneWidget);
  });

  testWidgets('stale banner and last known at 6 s, lost at 30 s', (tester) async {
    await pump(tester);
    link.handleFrame(makeFrame());
    now = 6000;
    link.notifyListeners();
    await tester.pump();
    expect(find.text('STALE: no packet for 6 s'), findsOneWidget);
    expect(find.text('last known'), findsWidgets);
    now = 31000;
    link.notifyListeners();
    await tester.pump();
    expect(find.text('LOST: no packet for 31 s'), findsOneWidget);
  });

  testWidgets('warning can be dismissed after 20 s; chip stays; next outage warns again', (tester) async {
    await pump(tester);
    link.handleFrame(makeFrame());
    now = 6000;
    link.notifyListeners();
    await tester.pump();
    expect(find.byKey(const Key('dismissWarning')), findsNothing); // too early to dismiss

    now = 21000;
    link.notifyListeners();
    await tester.pump();
    await tester.tap(find.byKey(const Key('dismissWarning')));
    await tester.pump();
    expect(find.textContaining('STALE'), findsNothing);
    expect(find.text('No link 0:21'), findsOneWidget);
    expect(find.text('last known'), findsWidgets); // the data is still marked old

    now = 42000; // goes LOST: still dismissed, chip keeps counting
    link.notifyListeners();
    await tester.pump();
    expect(find.textContaining('LOST'), findsNothing);
    expect(find.text('No link 0:42'), findsOneWidget);

    link.handleFrame(makeFrame(seq: 1, timeMs: 2000)); // frames resume
    await tester.pump();
    expect(find.textContaining('No link'), findsNothing);
    expect(find.text('last known'), findsNothing);

    now = 48000; // the link drops again: full banner is back
    link.notifyListeners();
    await tester.pump();
    expect(find.text('STALE: no packet for 6 s'), findsOneWidget);
    expect(find.textContaining('No link'), findsNothing);
  });

  testWidgets('auto-hide setting hides the banner by itself at 20 s', (tester) async {
    settings.autoHideWarning = true;
    await pump(tester);
    link.handleFrame(makeFrame());
    now = 6000;
    link.notifyListeners();
    await tester.pump();
    expect(find.text('STALE: no packet for 6 s'), findsOneWidget);
    now = 85000;
    link.notifyListeners();
    await tester.pump();
    expect(find.textContaining('LOST'), findsNothing);
    expect(find.text('No link 1:25'), findsOneWidget);
    expect(find.text('last known'), findsWidgets);
  });

  testWidgets('max altitude resets on a new session', (tester) async {
    await pump(tester);
    link.handleFrame(makeFrame(seq: 0, baroAltCm: 50000, phase: Phase.coast));
    link.handleFrame(makeFrame(seq: 1, timeMs: 2000, baroAltCm: 100, phase: Phase.landed));
    expect(link.maxAltM, 500.0);
    link.handleFrame(makeFrame(seq: 2, timeMs: 3000, baroAltCm: 20, phase: Phase.pad));
    expect(link.maxAltM, 0.2);
  });

  testWidgets('feet switch changes the main unit', (tester) async {
    await pump(tester);
    link.handleFrame(makeFrame(baroAltCm: 10000));
    settings.useFeet = true;
    await tester.pump();
    expect(find.text('328 ft'), findsNWidgets(2));
    expect(find.text('100.0 m'), findsNWidgets(2));
  });
}

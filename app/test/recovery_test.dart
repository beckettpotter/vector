import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/screens/recovery_screen.dart';
import 'package:vector/settings.dart';
import 'package:vector/theme.dart';

import 'helpers.dart';

void main() {
  testWidgets('after the sample flight lands: about 620 m at 76 degrees ENE from the pad', (tester) async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final settings = AppSettings();
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    await tester.pumpWidget(MaterialApp(
        theme: buildVectorTheme(), home: Scaffold(body: RecoveryView(link: link, settings: settings))));
    expect(find.text('No rocket position yet'), findsOneWidget);

    final frames = sampleFlight();
    for (final f in frames.take(30)) {
      link.handleFrame(f);
    }
    await tester.pump();
    expect(find.textContaining('ROCKET STILL FLYING'), findsOneWidget);

    for (final f in frames.skip(30)) {
      link.handleFrame(f);
    }
    await tester.pump();
    expect(find.textContaining('ROCKET STILL FLYING'), findsNothing);
    expect(find.text('620 m'), findsOneWidget);
    expect(find.text('76°  ENE'), findsOneWidget);
    expect(find.text('32.9913517, -106.9685540'), findsOneWidget);
    expect(settings.viewerLat, closeTo(32.99, 1e-9)); // pre-filled with the pad

    // Typing a new viewer position updates the answer.
    await tester.enterText(find.byKey(const Key('viewerLat')), '32.9913517');
    await tester.enterText(find.byKey(const Key('viewerLon')), '-106.9685540');
    await tester.pump();
    expect(find.text('0 m'), findsOneWidget);
    link.dispose();
  });
}

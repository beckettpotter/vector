import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/screens/track_screen.dart';
import 'package:vector/theme.dart';

import 'helpers.dart';

void main() {
  testWidgets('track plot draws the whole sample flight without throwing', (tester) async {
    final link = LinkController(nowMs: () => 0, tick: false);
    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(MaterialApp(theme: buildVectorTheme(), home: Scaffold(body: TrackView(link: link))));
    expect(find.text('No GPS position yet'), findsOneWidget);
    final frames = sampleFlight();
    for (final f in frames) {
      link.handleFrame(f);
      if (f.packet.seq % 20 == 0) await tester.pump();
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('620 m from pad'), findsOneWidget);
    link.dispose();
  });
}

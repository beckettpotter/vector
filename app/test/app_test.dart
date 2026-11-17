import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/main.dart';
import 'package:vector/services.dart';
import 'package:vector/settings.dart';
import 'package:vector/storage/flight_store.dart';
import 'package:vector/storage/recorder.dart';

Services testServices() {
  final link = LinkController(tick: false);
  final store = FlightStore(Directory('${Directory.systemTemp.path}/vector_app_test_unused'));
  return Services(link: link, settings: AppSettings(), store: store, recorder: Recorder(store: store, link: link));
}

void main() {
  testWidgets('shows the Vector title and the waiting line', (tester) async {
    final s = testServices();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(VectorApp(services: s));
    expect(find.text('Vector'), findsOneWidget);
    expect(find.text('Waiting for a rocket'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    s.link.dispose();
  });
}

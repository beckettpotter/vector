import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/checklist.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/location.dart';
import 'package:vector/screens/preflight_screen.dart';
import 'package:vector/screens/recovery_screen.dart';
import 'package:vector/services.dart';
import 'package:vector/settings.dart';
import 'package:vector/storage/flight_store.dart';
import 'package:vector/storage/recorder.dart';
import 'package:vector/theme.dart';
import 'package:vector/time_display.dart';

import 'helpers.dart';

class FakeSource implements LocationSource {
  bool enabled = true;
  LocationPermit permit = LocationPermit.denied;
  LocationPermit answer = LocationPermit.granted;
  int requests = 0;
  bool throws = false;
  final controller = StreamController<DeviceFix>.broadcast();

  @override
  Future<bool> serviceEnabled() async {
    if (throws) throw UnsupportedError('no location here');
    return enabled;
  }

  @override
  Future<LocationPermit> checkPermission() async => permit;
  @override
  Future<LocationPermit> requestPermission() async {
    requests++;
    return permit = answer;
  }

  @override
  Stream<DeviceFix> positions() => controller.stream;
}

DeviceFix hearne({double lat = 30.8721, double lon = -96.6222}) =>
    DeviceFix(lat: lat, lon: lon, accuracyM: 5, at: DateTime.utc(2026, 12, 12));

void main() {
  test('off by default; on after a yes; positions stay in memory', () async {
    final src = FakeSource();
    final loc = DeviceLocation(src);
    expect(loc.state, LocationState.off);
    await loc.start();
    expect(src.requests, 1);
    expect(loc.state, LocationState.on);
    src.controller.add(hearne());
    await Future.delayed(Duration.zero);
    expect(loc.fix!.lat, 30.8721);
    expect(loc.timeZone, chicagoZone); // the zone at Hearne, found offline
    loc.stop();
    expect(loc.fix, isNull);
    expect(loc.state, LocationState.off);
    expect(src.controller.hasListener, isFalse);
  });

  test('a no from the system, no service, or no plugin: calm states, never a crash', () async {
    final src = FakeSource()..answer = LocationPermit.denied;
    final loc = DeviceLocation(src);
    await loc.start();
    expect(loc.state, LocationState.denied);

    src
      ..permit = LocationPermit.deniedForever
      ..requests = 0;
    await loc.start();
    expect(src.requests, 0); // "don't ask again" is respected: no repeat nagging
    expect(loc.state, LocationState.denied);

    src.enabled = false;
    await loc.start();
    expect(loc.state, LocationState.unavailable);

    src.throws = true;
    await loc.start();
    expect(loc.state, LocationState.unavailable);
  });

  test('at start-up it never prompts; in the background it stops listening', () async {
    final src = FakeSource();
    final loc = DeviceLocation(src);
    await loc.start(ask: false);
    expect(src.requests, 0);
    expect(loc.state, LocationState.denied);

    src.permit = LocationPermit.granted;
    await loc.start(ask: false);
    expect(loc.state, LocationState.on);
    expect(src.controller.hasListener, isTrue);
    loc.setPaused(true);
    expect(src.controller.hasListener, isFalse);
    loc.setPaused(false);
    expect(src.controller.hasListener, isTrue);
    loc.stop();
  });

  test('"From my location" time zone follows the device position while location is on', () async {
    final src = FakeSource()..permit = LocationPermit.granted;
    final link = LinkController(nowMs: () => 0, tick: false);
    final store = FlightStore(Directory.systemTemp);
    final settings = AppSettings()..timeZone = locationZoneSetting;
    final s = Services(
        link: link,
        settings: settings,
        store: store,
        recorder: Recorder(store: store, link: link),
        location: DeviceLocation(src));
    await s.location.start();
    src.controller.add(hearne(lat: 39.74, lon: -104.99)); // Denver
    await Future.delayed(Duration.zero);
    expect(settings.locationTimeZone, 'America/Denver');
    expect(settings.formatTime(DateTime.utc(2026, 12, 12, 18)), '2026-12-12 11:00 Denver time');
    s.location.stop();
    expect(settings.locationTimeZone, isNull);
    s.recorder.dispose();
    link.dispose();
  });

  testWidgets('Vector explains first; "Not now" never shows the system prompt', (tester) async {
    final src = FakeSource();
    final loc = DeviceLocation(src);
    final settings = AppSettings();
    final link = LinkController(nowMs: () => 0, tick: false);
    await tester.binding.setSurfaceSize(const Size(1000, 3200));
    await tester.pumpWidget(MaterialApp(
      theme: buildVectorTheme(),
      home: Scaffold(
          body: PreflightView(link: link, settings: settings, checklist: Checklist(), location: loc)),
    ));
    expect(find.text('Off. Vector uses positions you type.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('useLocation')));
    await tester.pumpAndSettle();
    expect(find.text('Use your location?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locationNotNow')));
    await tester.pumpAndSettle();
    expect(src.requests, 0);
    expect(settings.useLocation, isFalse);

    src.answer = LocationPermit.denied;
    await tester.tap(find.byKey(const Key('useLocation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('locationYes')));
    await tester.pumpAndSettle();
    expect(src.requests, 1);
    expect(settings.useLocation, isFalse);
    expect(find.textContaining("Location wasn't allowed"), findsOneWidget);

    src.answer = LocationPermit.granted;
    await tester.tap(find.byKey(const Key('useLocation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('locationYes')));
    await tester.pumpAndSettle();
    expect(settings.useLocation, isTrue);
    src.controller.add(hearne());
    await tester.pump();
    await tester.pump(); // the position arrives, then the screen redraws
    expect(find.text('On. Accurate to about 5 m.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('useLocation'))); // turn it off again
    await tester.pumpAndSettle();
    expect(settings.useLocation, isFalse);
    expect(loc.fix, isNull);
    link.dispose();
  });

  testWidgets('Recovery uses the device position, and typing still works', (tester) async {
    final src = FakeSource()..permit = LocationPermit.granted;
    final loc = DeviceLocation(src);
    await loc.start();
    final link = LinkController(nowMs: () => 0, tick: false);
    final settings = AppSettings();
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    await tester.pumpWidget(MaterialApp(
        theme: buildVectorTheme(),
        home: Scaffold(body: RecoveryView(link: link, settings: settings, location: loc))));
    for (final f in sampleFlight()) {
      link.handleFrame(f);
    }
    await tester.pump();
    expect(find.textContaining('Waiting for this device'), findsOneWidget);
    expect(find.text('620 m'), findsOneWidget); // typed (pad) position until a fix arrives

    src.controller.add(hearne(lat: 32.9913517, lon: -106.9685540)); // standing at the landing spot
    await tester.pump();
    await tester.pump();
    expect(find.text('0 m'), findsOneWidget);
    expect(find.textContaining('From this device'), findsOneWidget);
    expect(find.byKey(const Key('viewerLat')), findsNothing);

    await tester.tap(find.byKey(const Key('typeInstead')));
    await tester.pump();
    expect(find.byKey(const Key('viewerLat')), findsOneWidget);
    expect(find.text('620 m'), findsOneWidget);
    loc.stop();
    link.dispose();
  });
}

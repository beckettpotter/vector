import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/protocol/packet.dart';
import 'package:vector/services.dart';
import 'package:vector/settings.dart';
import 'package:vector/storage/flight_store.dart';
import 'package:vector/storage/recorder.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await AppSettings.load();
    expect(a.useFeet, isFalse);
    expect(a.autoHideWarning, isFalse);
    expect(a.address, simulatorAddress);
    a.useFeet = true;
    a.autoHideWarning = true;
    a.address = groundNodeAddress;
    a.profiles.add(RocketProfile(name: 'Big Red', motor: 'H128W', massKg: 1.8, trackerId: 7));
    a.saveProfiles();
    a.lastRocketName = 'Big Red';
    await Future.delayed(Duration.zero);

    final b = await AppSettings.load(); // a fresh start reads the saved values
    expect(b.useFeet, isTrue);
    expect(b.autoHideWarning, isTrue);
    expect(b.address, groundNodeAddress);
    expect(b.lastRocketName, 'Big Red');
    expect(b.profiles.single.motor, 'H128W');
    expect(b.profiles.single.trackerId, 7);
  });

  test('broken saved values fall back to defaults instead of crashing', () async {
    SharedPreferences.setMockInitialValues({'profiles': 'not json', 'address': 42, 'useFeet': 'yes'});
    final s = await AppSettings.load();
    expect(s.profiles, isEmpty);
    expect(s.address, simulatorAddress);
    expect(s.useFeet, isFalse);
  });

  test('profile lookup: matching tracker id first, then the chosen rocket without an id', () {
    final s = AppSettings()
      ..profiles = [
        RocketProfile(name: 'A', trackerId: 1),
        RocketProfile(name: 'B'),
      ];
    expect(s.profileFor(1)!.name, 'A');
    expect(s.profileFor(2), isNull);
    s.lastRocketName = 'B';
    expect(s.profileFor(2)!.name, 'B');
  });

  test('checklist ticks reset at launch and on a new session', () {
    final link = LinkController(nowMs: () => 0, tick: false);
    final store = FlightStore(Directory('${Directory.systemTemp.path}/vector_unused'));
    final s = Services(link: link, settings: AppSettings(), store: store, recorder: Recorder(store: store, link: link));
    link.handleFrame(makeFrame(seq: 0));
    s.checklist.toggle('Tracker armed');
    link.handleFrame(makeFrame(seq: 1, timeMs: 2000));
    expect(s.checklist.ticked, {'Tracker armed'});
    link.handleFrame(makeFrame(seq: 2, timeMs: 3000, phase: Phase.boost));
    expect(s.checklist.ticked, isEmpty);
    s.checklist.toggle('Signal check');
    link.handleFrame(makeFrame(rocketId: 9, seq: 0, timeMs: 1000));
    expect(s.checklist.ticked, isEmpty);
    s.recorder.dispose();
    link.dispose();
  });
}

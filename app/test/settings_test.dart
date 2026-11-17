import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector/checklist.dart';
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

  test('checklist ticks reset at launch and on a new session', () async {
    final link = LinkController(nowMs: () => 0, tick: false);
    final tmp = Directory.systemTemp.createTempSync('vector_checklist_');
    final store = FlightStore(tmp);
    final s = Services(link: link, settings: AppSettings(), store: store, recorder: Recorder(store: store, link: link));
    link.handleFrame(makeFrame(seq: 0));
    s.checklist.toggle('armed');
    link.handleFrame(makeFrame(seq: 1, timeMs: 2000));
    expect(s.checklist.ticked, {'armed'});
    link.handleFrame(makeFrame(seq: 2, timeMs: 3000, phase: Phase.boost));
    expect(s.checklist.ticked, isEmpty);
    expect(s.checklist.launchSnapshot!.firstWhere((c) => c.text == 'Tracker armed').ticked, isTrue);
    s.checklist.toggle('signal');
    link.handleFrame(makeFrame(seq: 3, timeMs: 4000, phase: Phase.boost)); // still the same launch
    expect(s.checklist.ticked, {'signal'});
    expect(s.checklist.launchSnapshot!.firstWhere((c) => c.text == 'Tracker armed').ticked, isTrue);
    link.handleFrame(makeFrame(rocketId: 9, seq: 0, timeMs: 1000));
    expect(s.checklist.ticked, isEmpty);
    await s.recorder.flush();
    s.recorder.dispose();
    link.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('checklist items and notes survive a restart; ticks do not', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await Checklist.load();
    expect(a.items.map((i) => i.id), ['armed', 'gps', 'battery', 'signal', 'rso']);
    a.add('Igniter continuity');
    a.edit(a.items.first, text: 'Tracker switched on', note: 'Switch is under the nose cone');
    a.move(a.items.last, -1);
    a.remove(a.items.firstWhere((i) => i.id == 'signal'));
    a.toggle('armed');
    a.launchNotes = 'Wind 5 mph from the south';
    await Future.delayed(Duration.zero);

    final b = await Checklist.load();
    expect(b.items.map((i) => i.text),
        ['Tracker switched on', 'GPS fix on the pad', 'Battery above 3.7 V', 'Igniter continuity', 'Club RSO approval']);
    expect(b.items.first.id, 'armed'); // renamed, still the built-in item with its live hint
    expect(b.items.first.note, 'Switch is under the nose cone');
    expect(b.launchNotes, 'Wind 5 mph from the south');
    expect(b.ticked, isEmpty);

    b.resetToDefaults();
    expect(b.items.map((i) => i.text).first, 'Tracker armed');
    expect(b.items.every((i) => i.note.isEmpty), isTrue);
    expect(b.launchNotes, 'Wind 5 mph from the south');
  });

  test('a broken saved checklist falls back to the defaults', () async {
    SharedPreferences.setMockInitialValues({'checklistItems': '[{"id": 3}]', 'launchNotes': 7});
    final c = await Checklist.load();
    expect(c.items.length, 5);
    expect(c.launchNotes, '');
  });
}

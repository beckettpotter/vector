import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage/flight_store.dart' show CheckedItem, FlightMeta;

class ChecklistItem {
  /// Built-in items keep their id when renamed, so their live hint keeps
  /// working ('armed', 'gps', 'battery', 'signal', 'rso'). Added items get 'u…'.
  final String id;
  String text;
  String note;
  ChecklistItem({required this.id, required this.text, this.note = ''});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'note': note};

  factory ChecklistItem.fromJson(Map<String, dynamic> j) =>
      ChecklistItem(id: j['id'] as String, text: j['text'] as String, note: j['note'] as String? ?? '');
}

List<ChecklistItem> defaultChecklistItems() => [
      ChecklistItem(id: 'armed', text: 'Tracker armed'),
      ChecklistItem(id: 'gps', text: 'GPS fix on the pad'),
      ChecklistItem(id: 'battery', text: 'Battery above 3.7 V'),
      ChecklistItem(id: 'signal', text: 'Signal check'),
      ChecklistItem(id: 'rso', text: 'Club RSO approval'),
    ];

/// Pre-flight checklist. Items, their notes and the launch notes are saved on
/// this device; ticks are not, and clear at each launch. Every storage read is
/// guarded: anything missing or broken falls back to the defaults.
class Checklist extends ChangeNotifier {
  SharedPreferences? _prefs;
  List<ChecklistItem> items = defaultChecklistItems();
  final Set<String> ticked = {};
  String _launchNotes = '';

  /// What the checklist looked like just before the ticks last cleared for a
  /// launch. Saved into the flight record.
  List<CheckedItem>? launchSnapshot;
  String launchSnapshotNotes = '';

  Checklist();

  static Future<Checklist> load() async {
    final c = Checklist();
    try {
      final p = await SharedPreferences.getInstance();
      c._prefs = p;
      try {
        final raw = p.getString('checklistItems');
        if (raw != null) {
          c.items = [
            for (final e in jsonDecode(raw) as List) ChecklistItem.fromJson(e as Map<String, dynamic>),
          ];
        }
      } catch (_) {
        c.items = defaultChecklistItems();
      }
      try {
        c._launchNotes = p.getString('launchNotes') ?? '';
      } catch (_) {
        c._launchNotes = '';
      }
    } catch (_) {
      // Storage unavailable: run with the defaults.
    }
    return c;
  }

  void _saveItems() {
    final text = jsonEncode([for (final i in items) i.toJson()]);
    _prefs?.setString('checklistItems', text).catchError((_) => false);
    notifyListeners();
  }

  String get launchNotes => _launchNotes;
  set launchNotes(String v) {
    if (v == _launchNotes) return;
    _launchNotes = v;
    _prefs?.setString('launchNotes', v).catchError((_) => false);
    notifyListeners();
  }

  void toggle(String id) {
    ticked.contains(id) ? ticked.remove(id) : ticked.add(id);
    notifyListeners();
  }

  void add(String text) {
    items.add(ChecklistItem(id: 'u${DateTime.now().microsecondsSinceEpoch}', text: text));
    _saveItems();
  }

  void edit(ChecklistItem item, {String? text, String? note}) {
    if (text != null) item.text = text;
    if (note != null) item.note = note;
    _saveItems();
  }

  void remove(ChecklistItem item) {
    items.remove(item);
    ticked.remove(item.id);
    _saveItems();
  }

  /// Move an item up (-1) or down (+1).
  void move(ChecklistItem item, int by) {
    final i = items.indexOf(item);
    final j = i + by;
    if (i < 0 || j < 0 || j >= items.length) return;
    items
      ..removeAt(i)
      ..insert(j, item);
    _saveItems();
  }

  /// Back to the built-in items. Notes on items are lost; the launch notes stay.
  void resetToDefaults() {
    items = defaultChecklistItems();
    ticked.clear();
    _saveItems();
  }

  List<CheckedItem> snapshot() =>
      [for (final i in items) CheckedItem(text: i.text, ticked: ticked.contains(i.id), note: i.note)];

  /// Called at each launch and new tracker session: remember what was checked,
  /// then clear the ticks.
  void startLaunch() {
    launchSnapshot = snapshot();
    launchSnapshotNotes = _launchNotes;
    reset();
  }

  /// Put the checklist as it was at launch into a new flight record.
  void fillFlight(FlightMeta meta) {
    meta.checklist = launchSnapshot ?? snapshot();
    meta.launchNotes = launchSnapshot == null ? _launchNotes : launchSnapshotNotes;
  }

  void reset() {
    if (ticked.isEmpty) return;
    ticked.clear();
    notifyListeners();
  }
}

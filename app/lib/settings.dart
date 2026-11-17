import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'link/link_controller.dart' show simulatorAddress;

class RocketProfile {
  String name;
  String motor;
  double? massKg;
  int? trackerId;
  String notes;
  RocketProfile({required this.name, this.motor = '', this.massKg, this.trackerId, this.notes = ''});

  Map<String, dynamic> toJson() =>
      {'name': name, 'motor': motor, 'massKg': massKg, 'trackerId': trackerId, 'notes': notes};

  factory RocketProfile.fromJson(Map<String, dynamic> j) => RocketProfile(
        name: j['name'] as String? ?? 'Rocket',
        motor: j['motor'] as String? ?? '',
        massKg: (j['massKg'] as num?)?.toDouble(),
        trackerId: (j['trackerId'] as num?)?.toInt(),
        notes: j['notes'] as String? ?? '',
      );
}

/// User choices shared by the screens, saved across restarts. Every read is
/// guarded: a missing or broken saved value falls back to the default.
class AppSettings extends ChangeNotifier {
  SharedPreferences? _prefs;

  AppSettings();

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final p = await SharedPreferences.getInstance();
      s._prefs = p;
      s._useFeet = _read(() => p.getBool('useFeet'), false);
      s._autoHideWarning = _read(() => p.getBool('autoHideWarning'), false);
      s._address = _read(() => p.getString('address'), simulatorAddress);
      s._lastRocketName = _read(() => p.getString('lastRocketName'), '');
      s.profiles = _read(
          () => (jsonDecode(p.getString('profiles') ?? '[]') as List)
              .map((e) => RocketProfile.fromJson(e as Map<String, dynamic>))
              .toList(),
          <RocketProfile>[]);
    } catch (_) {
      // Settings storage unavailable: run with defaults.
    }
    return s;
  }

  static T _read<T>(T? Function() f, T fallback) {
    try {
      return f() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  void _save(Future<bool> Function(SharedPreferences p) write) {
    final p = _prefs;
    if (p == null) return;
    write(p).catchError((_) => false);
  }

  bool _useFeet = false;
  bool get useFeet => _useFeet;
  set useFeet(bool v) {
    if (v == _useFeet) return;
    _useFeet = v;
    _save((p) => p.setBool('useFeet', v));
    notifyListeners();
  }

  /// Hide the STALE/LOST banner by itself once it can be dismissed (20 s).
  bool _autoHideWarning = false;
  bool get autoHideWarning => _autoHideWarning;
  set autoHideWarning(bool v) {
    if (v == _autoHideWarning) return;
    _autoHideWarning = v;
    _save((p) => p.setBool('autoHideWarning', v));
    notifyListeners();
  }

  String _address = simulatorAddress;
  String get address => _address;
  set address(String v) {
    if (v == _address) return;
    _address = v;
    _save((p) => p.setString('address', v));
    notifyListeners();
  }

  /// Name of the rocket profile chosen as "flying now" ('' = none).
  String _lastRocketName = '';
  String get lastRocketName => _lastRocketName;
  set lastRocketName(String v) {
    _lastRocketName = v;
    _save((p) => p.setString('lastRocketName', v));
    notifyListeners();
  }

  List<RocketProfile> profiles = [];
  void saveProfiles() {
    final text = jsonEncode([for (final r in profiles) r.toJson()]);
    _save((p) => p.setString('profiles', text));
    notifyListeners();
  }

  /// The profile for a tracker: one whose tracker id matches, else the chosen
  /// rocket if it has no tracker id set.
  RocketProfile? profileFor(int rocketId) {
    for (final r in profiles) {
      if (r.trackerId == rocketId) return r;
    }
    for (final r in profiles) {
      if (r.name == _lastRocketName && r.trackerId == null) return r;
    }
    return null;
  }

  /// The recovery viewer's typed position (device GPS is not used yet). Not saved.
  double? viewerLat;
  double? viewerLon;
}

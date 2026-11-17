import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

/// One position from this device. Kept in memory only.
class DeviceFix {
  final double lat;
  final double lon;
  final double accuracyM;
  final DateTime at;
  const DeviceFix({required this.lat, required this.lon, required this.accuracyM, required this.at});
}

enum LocationPermit { granted, denied, deniedForever, unavailable }

/// The operating system's location service, behind a small interface so tests
/// can use a fake. Only "while the app is in use" is ever requested.
abstract class LocationSource {
  Future<bool> serviceEnabled();
  Future<LocationPermit> checkPermission();
  Future<LocationPermit> requestPermission();
  Stream<DeviceFix> positions();
}

class GeolocatorSource implements LocationSource {
  static LocationPermit _map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocationPermit.granted,
        LocationPermission.deniedForever => LocationPermit.deniedForever,
        LocationPermission.unableToDetermine => LocationPermit.unavailable,
        LocationPermission.denied => LocationPermit.denied,
      };

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermit> checkPermission() async => _map(await Geolocator.checkPermission());
  @override
  Future<LocationPermit> requestPermission() async => _map(await Geolocator.requestPermission());
  @override
  Stream<DeviceFix> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1),
      ).map((p) => DeviceFix(lat: p.latitude, lon: p.longitude, accuracyM: p.accuracy, at: p.timestamp));
}

enum LocationState {
  /// The user has not turned it on (the default).
  off,
  starting,
  on,

  /// The user or the system said no.
  denied,

  /// This device has no location service, or it is switched off.
  unavailable,
}

/// "Use my location": off by default, started only from a tap (or at start-up
/// if the user turned it on before and the permission is still granted, with
/// no prompt), paused while the app is in the background, never saved and
/// never sent anywhere.
class DeviceLocation extends ChangeNotifier {
  final LocationSource source;
  DeviceLocation(this.source);

  LocationState state = LocationState.off;
  DeviceFix? fix;
  StreamSubscription<DeviceFix>? _sub;
  bool _paused = false;

  bool get isOn => state == LocationState.on || state == LocationState.starting;

  /// The IANA zone at the current position (for the time-zone setting).
  String? get timeZone {
    final f = fix;
    if (f == null) return null;
    try {
      final z = tzmap.latLngToTimezoneString(f.lat, f.lon);
      return z.isEmpty ? null : z;
    } catch (_) {
      return null;
    }
  }

  /// After the user agreed to Vector's explanation. [ask] false means never
  /// show the system prompt (used at start-up).
  Future<void> start({bool ask = true}) async {
    state = LocationState.starting;
    notifyListeners();
    try {
      if (!await source.serviceEnabled()) {
        state = LocationState.unavailable;
        notifyListeners();
        return;
      }
      var permit = await source.checkPermission();
      if (permit == LocationPermit.denied && ask) permit = await source.requestPermission();
      if (permit != LocationPermit.granted) {
        state = permit == LocationPermit.unavailable ? LocationState.unavailable : LocationState.denied;
        notifyListeners();
        return;
      }
      state = LocationState.on;
      notifyListeners();
      _listen();
    } catch (_) {
      // No plugin for this platform, no GeoClue on Linux, and so on.
      state = LocationState.unavailable;
      notifyListeners();
    }
  }

  void _listen() {
    _sub?.cancel();
    if (_paused) return;
    _sub = source.positions().listen((f) {
      fix = f;
      notifyListeners();
    }, onError: (_) {
      state = LocationState.unavailable;
      _sub?.cancel();
      _sub = null;
      notifyListeners();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    fix = null;
    state = LocationState.off;
    notifyListeners();
  }

  /// The app went to the background (true) or came back (false).
  void setPaused(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    if (paused) {
      _sub?.cancel();
      _sub = null;
    } else if (state == LocationState.on) {
      _listen();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

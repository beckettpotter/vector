import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'checklist.dart';
import 'link/link_controller.dart';
import 'protocol/packet.dart';
import 'settings.dart';
import 'storage/flight_store.dart';
import 'storage/recorder.dart';

/// Everything the screens share, created once at start-up.
class Services {
  final LinkController link;
  final AppSettings settings;
  final FlightStore store;
  final Recorder recorder;
  final Checklist checklist;

  Services({required this.link, required this.settings, required this.store, required this.recorder, Checklist? checklist})
      : checklist = checklist ?? Checklist() {
    // Checklist ticks clear at each launch and each new tracker session,
    // after a snapshot is kept for the flight record.
    var boostSeen = false;
    link.frameListeners.add((frame, newSession) {
      final boost = frame.packet.phase == Phase.boost;
      if (newSession || (boost && !boostSeen)) this.checklist.startLaunch();
      if (newSession) boostSeen = false;
      if (boost) boostSeen = true;
    });
  }

  static Future<Services> create() async {
    final settings = await AppSettings.load();
    final checklist = await Checklist.load();
    final link = LinkController()..address = settings.address;
    final store = FlightStore(await flightsFolder());
    final recorder = Recorder(
      store: store,
      link: link,
      nameFor: (rocketId, started) {
        final profile = settings.profileFor(rocketId);
        final base = defaultFlightName(rocketId, started, formatTime: settings.formatTime);
        return profile == null ? base : base.replaceFirst('Rocket $rocketId', profile.name);
      },
      fillMeta: checklist.fillFlight,
    );
    final services =
        Services(link: link, settings: settings, store: store, recorder: recorder, checklist: checklist);
    services._watchLink();
    return services;
  }

  bool _awake = false;

  void _watchLink() {
    link.addListener(() {
      // Remember the address that was last used to connect.
      if (link.isActive && link.source?.isReplay == false) settings.address = link.address;
      // Keep the screen on while connected so the HUD stays visible at the field.
      final want = link.isActive;
      if (want != _awake) {
        _awake = want;
        (want ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
      }
    });
  }
}

/// `<documents>/Vector/flights`. If the documents folder is unavailable, use
/// the app's own permanent data folder; a temporary folder is the last resort
/// so the app still starts.
Future<Directory> flightsFolder() async {
  final sep = Platform.pathSeparator;
  for (final base in [getApplicationDocumentsDirectory, getApplicationSupportDirectory]) {
    try {
      final dir = Directory('${(await base()).path}${sep}Vector${sep}flights');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      continue;
    }
  }
  return Directory('${Directory.systemTemp.path}${sep}vector_flights');
}

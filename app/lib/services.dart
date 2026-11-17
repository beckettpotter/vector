import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'link/link_controller.dart';
import 'settings.dart';
import 'storage/flight_store.dart';
import 'storage/recorder.dart';

/// Everything the screens share, created once at start-up.
class Services {
  final LinkController link;
  final AppSettings settings;
  final FlightStore store;
  final Recorder recorder;
  Services({required this.link, required this.settings, required this.store, required this.recorder});

  static Future<Services> create() async {
    final link = LinkController();
    final settings = AppSettings();
    final store = FlightStore(await flightsFolder());
    return Services(link: link, settings: settings, store: store, recorder: Recorder(store: store, link: link));
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

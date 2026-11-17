import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Clock times are stored in UTC everywhere (flight files, CSV, KML). This file
/// only turns a stored UTC time into words for the screen, in the zone the user
/// chose. Durations ("time since last packet") are not clock times and never
/// come through here.
const String chicagoZone = 'America/Chicago';

/// Setting values that are not zone names.
const String deviceZoneSetting = 'device';
const String locationZoneSetting = 'location';

bool _loaded = false;

/// The zone database is built into the app, so this works with no internet.
void ensureTimeZones() {
  if (_loaded) return;
  tzdata.initializeTimeZones();
  _loaded = true;
}

bool isKnownZone(String name) {
  ensureTimeZones();
  return tz.timeZoneDatabase.locations.containsKey(name);
}

/// Every zone name in the database, sorted, for the "pick a zone" list.
List<String> allZoneNames() {
  ensureTimeZones();
  return tz.timeZoneDatabase.locations.keys.where((n) => n.contains('/')).toList()..sort();
}

/// 'America/Chicago' -> 'Chicago time', 'America/Argentina/Buenos_Aires' ->
/// 'Buenos Aires time'. Never a fixed abbreviation like CST, which is wrong for
/// half the year.
String zoneLabel(String zone) => '${zone.split('/').last.replaceAll('_', ' ')} time';

String _two(int v) => v.toString().padLeft(2, '0');

/// For example '2026-12-12 12:00 Chicago time'.
/// [zone] is an IANA name or [deviceZoneSetting]. An unknown name falls back
/// to Chicago, so a bad saved setting never breaks a screen.
String formatClock(DateTime t, String zone) {
  final u = t.toUtc();
  if (zone == deviceZoneSetting) {
    final l = u.toLocal();
    return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)} '
        "(this device's time, ${l.timeZoneName})";
  }
  if (!isKnownZone(zone)) zone = chicagoZone;
  final l = tz.TZDateTime.from(u, tz.getLocation(zone));
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)} ${zoneLabel(zone)}';
}

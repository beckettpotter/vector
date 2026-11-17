import 'package:material_ui/material_ui.dart';

import '../link/replay_link.dart';
import '../protocol/packet.dart';
import '../services.dart';
import '../storage/flight_store.dart';
import '../theme.dart';
import 'connect_box.dart';
import 'export_actions.dart';
import 'flight_detail_screen.dart';
import 'history_screen.dart';
import 'hud_screen.dart';
import 'preflight_screen.dart';
import 'recovery_screen.dart';
import 'replay_bar.dart';
import 'track_screen.dart';

class HomeScreen extends StatefulWidget {
  final Services services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1; // HUD

  // Location is never used in the background.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (state) => widget.services.location
        .setPaused(state == AppLifecycleState.paused || state == AppLifecycleState.hidden),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _replay(FlightRecord record, List<GroundFrame> frames) async {
    if (frames.isEmpty) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _tab = 1);
    await widget.services.link.useSource(ReplayLink(frames, name: record.meta.name, speed: 5));
  }

  late final DetailActions _actions = DetailActions((context, record, frames) => [
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Replay'),
          onPressed: () => _replay(record, frames),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.table_chart),
          label: const Text('Export CSV'),
          onPressed: () => exportFlight(context, record, frames, 'csv'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.public),
          label: const Text('Export KML'),
          onPressed: () => exportFlight(context, record, frames, 'kml'),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = widget.services;
    final link = s.link;
    final connect = ConnectBox(link: link);
    final hud = HudPanel(link: link, settings: s.settings);

    return Scaffold(
      appBar: AppBar(title: Text('Vector', style: text.headlineMedium?.copyWith(color: VxColors.accent))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Pre-flight'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'HUD'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Recovery'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([link, s.settings]),
            builder: (context, _) {
              final src = link.source;
              return Column(children: [
                if (src is ReplayLink) ReplayBar(link: link, replay: src),
                StaleBanner(link: link, settings: s.settings),
              ]);
            },
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              final Widget content = switch (_tab) {
                0 => PreflightView(link: link, settings: s.settings, checklist: s.checklist, location: s.location),
                2 => TrackView(link: link, location: s.location),
                3 => RecoveryView(link: link, settings: s.settings, location: s.location),
                4 => HistoryView(
                    store: s.store, recorder: s.recorder, settings: s.settings, actions: _actions, onReplay: _replay),
                _ => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [if (!wide) ...[connect, const SizedBox(height: 16)], hud],
                  ),
              };
              if (!wide) return content;
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 360, child: ListView(padding: const EdgeInsets.all(16), children: [connect])),
                Expanded(child: content),
              ]);
            }),
          ),
        ],
      ),
    );
  }
}

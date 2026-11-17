import 'package:material_ui/material_ui.dart';

import '../services.dart';
import '../theme.dart';
import 'connect_box.dart';
import 'history_screen.dart';
import 'hud_screen.dart';
import 'recovery_screen.dart';
import 'track_screen.dart';

class HomeScreen extends StatefulWidget {
  final Services services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

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
          NavigationDestination(icon: Icon(Icons.speed), label: 'HUD'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Recovery'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      body: Column(
        children: [
          ListenableBuilder(listenable: link, builder: (context, _) => StaleBanner(link: link)),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              final Widget content = switch (_tab) {
                1 => TrackView(link: link),
                2 => RecoveryView(link: link, settings: s.settings),
                3 => HistoryView(store: s.store, recorder: s.recorder),
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

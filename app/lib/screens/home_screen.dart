import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../settings.dart';
import '../theme.dart';
import 'connect_box.dart';
import 'hud_screen.dart';
import 'track_screen.dart';

class HomeScreen extends StatefulWidget {
  final LinkController link;
  final AppSettings settings;
  const HomeScreen({super.key, required this.link, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final link = widget.link;
    final connect = ConnectBox(link: link);
    final hud = HudPanel(link: link, settings: widget.settings);

    return Scaffold(
      appBar: AppBar(title: Text('Vector', style: text.headlineMedium?.copyWith(color: VxColors.accent))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.speed), label: 'HUD'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Track'),
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

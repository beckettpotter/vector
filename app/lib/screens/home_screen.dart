import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../settings.dart';
import '../theme.dart';
import 'connect_box.dart';
import 'hud_screen.dart';

class HomeScreen extends StatelessWidget {
  final LinkController link;
  final AppSettings settings;
  const HomeScreen({super.key, required this.link, required this.settings});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hud = HudPanel(link: link, settings: settings);
    final connect = ConnectBox(link: link);
    return Scaffold(
      appBar: AppBar(title: Text('Vector', style: text.headlineMedium?.copyWith(color: VxColors.accent))),
      body: Column(
        children: [
          ListenableBuilder(listenable: link, builder: (context, _) => StaleBanner(link: link)),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 1000) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 360, child: ListView(padding: const EdgeInsets.all(16), children: [connect])),
                  Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [hud])),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [connect, const SizedBox(height: 16), hud],
              );
            }),
          ),
        ],
      ),
    );
  }
}

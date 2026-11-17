import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../theme.dart';
import 'connect_box.dart';

class HomeScreen extends StatelessWidget {
  final LinkController link;
  const HomeScreen({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Vector', style: text.headlineMedium?.copyWith(color: VxColors.accent))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConnectBox(link: link),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: link,
            builder: (context, _) => link.monitor.frameCount == 0
                ? Center(child: Text('Waiting for a rocket', style: text.headlineMedium))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

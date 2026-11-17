import 'package:material_ui/material_ui.dart';

import 'link/link_controller.dart';
import 'screens/home_screen.dart';
import 'settings.dart';
import 'theme.dart';

void main() {
  runApp(VectorApp(link: LinkController(), settings: AppSettings()));
}

class VectorApp extends StatelessWidget {
  final LinkController link;
  final AppSettings settings;
  const VectorApp({super.key, required this.link, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vector',
      debugShowCheckedModeBanner: false,
      theme: buildVectorTheme(),
      home: HomeScreen(link: link, settings: settings),
    );
  }
}

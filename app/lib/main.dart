import 'package:material_ui/material_ui.dart';

import 'link/link_controller.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(VectorApp(link: LinkController()));
}

class VectorApp extends StatelessWidget {
  final LinkController link;
  const VectorApp({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vector',
      debugShowCheckedModeBanner: false,
      theme: buildVectorTheme(),
      home: HomeScreen(link: link),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'services.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(VectorApp(services: await Services.create()));
}

class VectorApp extends StatelessWidget {
  final Services services;
  const VectorApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vector',
      debugShowCheckedModeBanner: false,
      theme: buildVectorTheme(),
      home: HomeScreen(services: services),
    );
  }
}

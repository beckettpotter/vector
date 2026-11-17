import 'package:material_ui/material_ui.dart';

import 'theme.dart';

void main() {
  runApp(const VectorApp());
}

class VectorApp extends StatelessWidget {
  const VectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vector',
      debugShowCheckedModeBanner: false,
      theme: buildVectorTheme(),
      home: const WaitingScreen(),
    );
  }
}

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vector', style: text.displayLarge?.copyWith(color: VxColors.accent)),
            const SizedBox(height: 16),
            Text('Waiting for a rocket', style: text.headlineMedium),
          ],
        ),
      ),
    );
  }
}

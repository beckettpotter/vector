import 'package:flutter_test/flutter_test.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/main.dart';
import 'package:vector/settings.dart';

void main() {
  testWidgets('shows the Vector title and the waiting line', (tester) async {
    final link = LinkController(tick: false);
    await tester.pumpWidget(VectorApp(link: link, settings: AppSettings()));
    expect(find.text('Vector'), findsOneWidget);
    expect(find.text('Waiting for a rocket'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    link.dispose();
  });
}

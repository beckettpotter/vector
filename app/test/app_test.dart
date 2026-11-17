import 'package:flutter_test/flutter_test.dart';
import 'package:vector/main.dart';

void main() {
  testWidgets('shows the Vector title and the waiting line', (tester) async {
    await tester.pumpWidget(const VectorApp());
    expect(find.text('Vector'), findsOneWidget);
    expect(find.text('Waiting for a rocket'), findsOneWidget);
  });
}

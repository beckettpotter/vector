import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector/checklist.dart';
import 'package:vector/link/link_controller.dart';
import 'package:vector/screens/preflight_screen.dart';
import 'package:vector/settings.dart';
import 'package:vector/theme.dart';

void main() {
  late LinkController link;
  late Checklist checklist;

  setUp(() {
    link = LinkController(nowMs: () => 0, tick: false);
    checklist = Checklist();
  });
  tearDown(() => link.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 3000));
    await tester.pumpWidget(MaterialApp(
      theme: buildVectorTheme(),
      home: Scaffold(body: PreflightView(link: link, settings: AppSettings(), checklist: checklist)),
    ));
  }

  testWidgets('add, rename, move and delete checklist items', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('editChecklist')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('addChecklistItem')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('checklistDialogField')), 'Igniter continuity');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(checklist.items.last.text, 'Igniter continuity');

    await tester.tap(find.byTooltip('Move up').last);
    await tester.pump();
    expect(checklist.items[4].text, 'Igniter continuity');

    await tester.tap(find.byTooltip('Rename').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('checklistDialogField')), 'Tracker switched on');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(checklist.items.first.text, 'Tracker switched on');

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pump();
    expect(checklist.items.length, 5);
    expect(checklist.items.first.text, 'GPS fix on the pad');

    await tester.tap(find.text('Reset to defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(checklist.items.map((i) => i.text).first, 'Tracker armed');
  });

  testWidgets('item notes and launch notes', (tester) async {
    await pump(tester);
    expect(find.text('no live data'), findsWidgets); // live hints still shown
    await tester.tap(find.byTooltip('Add a note').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('checklistDialogField')), 'Switch under the nose cone');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Note: Switch under the nose cone'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('launchNotes')), 'Wind 5 mph');
    expect(checklist.launchNotes, 'Wind 5 mph');

    await tester.tap(find.text('Tracker armed'));
    await tester.pump();
    expect(checklist.ticked, {'armed'});
  });
}

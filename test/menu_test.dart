import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

Widget menuScene({
  List<String>? log,
  bool dark = false,
  GlassMenuAlign align = GlassMenuAlign.end,
}) {
  return scene(
    dark: dark,
    Padding(
      padding: EdgeInsets.only(
          bottom: 160, left: align == GlassMenuAlign.end ? 140 : 0, right: align == GlassMenuAlign.end ? 0 : 140),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassMenu(
            semanticLabel: 'More',
            align: align,
            items: [
              GlassMenuItem(
                label: const Text('Share'),
                icon: const Icon(Icons.ios_share),
                onSelected: () => log?.add('share'),
              ),
              GlassMenuItem(
                label: const Text('Duplicate'),
                icon: const Icon(Icons.copy),
                onSelected: () => log?.add('duplicate'),
              ),
              GlassMenuItem(
                label: const Text('Archive'),
                icon: const Icon(Icons.archive_outlined),
                enabled: false,
                onSelected: () => log?.add('archive'),
              ),
              const GlassMenuSeparator(),
              GlassMenuItem(
                label: const Text('Delete'),
                icon: const Icon(Icons.delete_outline),
                destructive: true,
                onSelected: () => log?.add('delete'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('opens on tap', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(menuScene());
    expect(find.text('Share'), findsNothing);
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('choosing a row calls it and closes', (tester) async {
    await setUpGlass(tester);
    final log = <String>[];
    await tester.pumpWidget(menuScene(log: log));
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    await tester.tap(find.text('Duplicate'));
    await settle(tester);
    expect(log, ['duplicate']);
    expect(find.text('Duplicate'), findsNothing);
  });

  testWidgets('a drag across rows chooses where it is let go', (tester) async {
    await setUpGlass(tester);
    final log = <String>[];
    await tester.pumpWidget(menuScene(log: log));
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Share')));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.text('Duplicate')));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.text('Delete')));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await settle(tester);
    expect(log, ['delete']);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('a press outside closes', (tester) async {
    await setUpGlass(tester);
    final log = <String>[];
    await tester.pumpWidget(menuScene(log: log));
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    await tester.tapAt(const Offset(10, 290));
    await settle(tester);
    expect(find.text('Share'), findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('a disabled row cannot be chosen', (tester) async {
    await setUpGlass(tester);
    final log = <String>[];
    await tester.pumpWidget(menuScene(log: log));
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);
    expect(log, isEmpty);
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('escape closes, arrows move focus, enter chooses', (tester) async {
    await setUpGlass(tester);
    final log = <String>[];
    await tester.pumpWidget(menuScene(log: log));
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Share'), findsNothing);

    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    // Focus starts on the first row: Share -> Duplicate -> Delete, as
    // Archive is disabled.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(log, ['delete']);
  });

  testWidgets('the trigger toggles the menu closed', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(menuScene());
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    expect(find.text('Share'), findsOneWidget);
    await tester.tap(find.byType(GlassButton), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Share'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('looks right open ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(360, 300), ratio: 2);
      await tester.pumpWidget(menuScene(dark: dark));
      await tester.tap(find.byType(GlassButton));
      await settle(tester);
      // A finger resting on a row shows the plate.
      final gesture = await tester.startGesture(tester.getCenter(find.text('Duplicate')));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/menu_${dark ? 'dark' : 'light'}.png'));
      await gesture.cancel();
      await settle(tester);
    });
  }

  testWidgets('looks right mid-morph', (tester) async {
    await setUpGlass(tester, size: const Size(360, 300), ratio: 2);
    await tester.pumpWidget(menuScene());
    await tester.tap(find.byType(GlassButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/menu_morph.png'));
    await settle(tester);
  });

  testWidgets('aligns to the start', (tester) async {
    await setUpGlass(tester, size: const Size(360, 300), ratio: 2);
    await tester.pumpWidget(menuScene(align: GlassMenuAlign.start));
    await tester.tap(find.byType(GlassButton));
    await settle(tester);
    final trigger = tester.getTopLeft(find.byType(GlassButton));
    final share = tester.getTopLeft(find.text('Share'));
    expect(share.dx, greaterThan(trigger.dx));
    expect(share.dx, lessThan(trigger.dx + 60));
  });
}

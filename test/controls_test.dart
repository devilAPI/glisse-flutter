import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

void main() {
  group('GlassCheckbox', () {
    testWidgets('toggles', (tester) async {
      await setUpGlass(tester);
      bool? value = false;
      await tester.pumpWidget(scene(StatefulBuilder(
        builder: (context, setState) => GlassCheckbox(value: value, onChanged: (v) => setState(() => value = v)),
      )));
      await tester.tap(find.byType(GlassCheckbox));
      await settle(tester);
      expect(value, isTrue);
      await tester.tap(find.byType(GlassCheckbox));
      await settle(tester);
      expect(value, isFalse);
    });

    testWidgets('tristate cycles through null', (tester) async {
      await setUpGlass(tester);
      bool? value = true;
      await tester.pumpWidget(scene(StatefulBuilder(
        builder: (context, setState) =>
            GlassCheckbox(value: value, tristate: true, onChanged: (v) => setState(() => value = v)),
      )));
      await tester.tap(find.byType(GlassCheckbox));
      await settle(tester);
      expect(value, isNull);
      await tester.tap(find.byType(GlassCheckbox));
      await settle(tester);
      expect(value, isFalse);
    });

    testWidgets('disabled ignores taps, space toggles when focused', (tester) async {
      await setUpGlass(tester);
      var calls = 0;
      await tester.pumpWidget(scene(const GlassCheckbox(value: false, onChanged: null)));
      await tester.tap(find.byType(GlassCheckbox), warnIfMissed: false);
      await settle(tester);
      expect(calls, 0);

      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(scene(GlassCheckbox(value: false, focusNode: focus, onChanged: (_) => calls++)));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(calls, 1);
    });
  });

  testWidgets('GlassRadio selects its value', (tester) async {
    await setUpGlass(tester);
    String? group = 'a';
    await tester.pumpWidget(scene(StatefulBuilder(
      builder: (context, setState) => Row(mainAxisSize: MainAxisSize.min, children: [
        GlassRadio<String>(
            key: const Key('a'), value: 'a', groupValue: group, onChanged: (v) => setState(() => group = v)),
        const SizedBox(width: 30),
        GlassRadio<String>(
            key: const Key('b'), value: 'b', groupValue: group, onChanged: (v) => setState(() => group = v)),
      ]),
    )));
    await tester.tap(find.byKey(const Key('b')));
    await settle(tester);
    expect(group, 'b');
    final semantics = tester.getSemantics(find.byKey(const Key('b')));
    expect(semantics.flagsCollection.isChecked, isTrue);
  });

  group('GlassStepper', () {
    testWidgets('steps and stops at its ends', (tester) async {
      await setUpGlass(tester);
      var value = 1.0;
      await tester.pumpWidget(scene(StatefulBuilder(
        builder: (context, setState) =>
            GlassStepper(value: value, min: 0, max: 2, onChanged: (v) => setState(() => value = v)),
      )));
      final box = tester.getRect(find.byType(GlassStepper));
      final plus = Offset(box.right - 20, box.center.dy);
      final minus = Offset(box.left + 20, box.center.dy);
      await tester.tapAt(plus);
      await settle(tester);
      expect(value, 2);
      await tester.tapAt(plus);
      await settle(tester);
      expect(value, 2);
      await tester.tapAt(minus);
      await tester.tapAt(minus);
      await tester.tapAt(minus);
      await settle(tester);
      expect(value, 0);
    });

    testWidgets('holding repeats', (tester) async {
      await setUpGlass(tester);
      var value = 0.0;
      await tester.pumpWidget(scene(StatefulBuilder(
        builder: (context, setState) =>
            GlassStepper(value: value, max: 100, onChanged: (v) => setState(() => value = v)),
      )));
      final box = tester.getRect(find.byType(GlassStepper));
      final gesture = await tester.startGesture(Offset(box.right - 20, box.center.dy));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);
      expect(value, greaterThan(3));
    });
  });

  testWidgets('GlassChip selects and deletes', (tester) async {
    await setUpGlass(tester);
    var selected = false;
    var deleted = false;
    await tester.pumpWidget(scene(StatefulBuilder(
      builder: (context, setState) => GlassChip(
        label: const Text('Photos'),
        selected: selected,
        onSelected: (v) => setState(() => selected = v),
        onDeleted: () => deleted = true,
      ),
    )));
    await tester.tap(find.text('Photos'));
    await settle(tester);
    expect(selected, isTrue);
    await tester.tap(find.bySemanticsLabel(RegExp('^Remove')));
    await settle(tester);
    expect(deleted, isTrue);
    expect(selected, isTrue);
  });

  testWidgets('progress bar animates to its value; indeterminate keeps running', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(const SizedBox(width: 200, child: GlassProgressBar(value: 0.3))));
    await tester.pumpWidget(scene(const SizedBox(width: 200, child: GlassProgressBar(value: 0.8))));
    await settle(tester);
    await tester.pumpWidget(scene(const SizedBox(width: 200, child: GlassProgressBar())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(scene(const SizedBox(width: 200, child: GlassProgressBar(value: 1))));
    await settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('activity indicator spins and stops', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(const GlassActivityIndicator()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(scene(const GlassActivityIndicator(animating: false)));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('page indicator taps report pages', (tester) async {
    await setUpGlass(tester);
    int? tapped;
    await tester.pumpWidget(scene(GlassPageIndicator(count: 5, page: 0, onTap: (i) => tapped = i)));
    final box = tester.getRect(find.byType(GlassPageIndicator));
    // The fourth dot: 10px of padding, then 16px per dot.
    await tester.tapAt(Offset(box.left + 10 + 3 * 16 + 3.5, box.center.dy));
    await settle(tester);
    expect(tapped, 3);
    expect(tester.getSize(find.byType(GlassPageIndicator)).width, 20 + 5 * 7 + 4 * 9);
  });

  testWidgets('badge pops in and out', (tester) async {
    await setUpGlass(tester);
    Widget badge(bool show) => scene(GlassBadge(label: '3', show: show, child: const SizedBox.square(dimension: 40)));
    await tester.pumpWidget(badge(false));
    expect(find.text('3'), findsNothing);
    await tester.pumpWidget(badge(true));
    await settle(tester);
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(badge(false));
    await settle(tester);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('button group items press on their own', (tester) async {
    await setUpGlass(tester);
    final pressed = <String>[];
    await tester.pumpWidget(scene(GlassButtonGroup(children: [
      GlassButtonGroupItem(icon: const Icon(Icons.undo), semanticLabel: 'Undo', onPressed: () => pressed.add('undo')),
      GlassButtonGroupItem(icon: const Icon(Icons.redo), semanticLabel: 'Redo', onPressed: () => pressed.add('redo')),
      const GlassButtonGroupItem(icon: Icon(Icons.delete), semanticLabel: 'Delete', onPressed: null),
    ])));
    await tester.tap(find.byIcon(Icons.redo));
    await tester.tap(find.byIcon(Icons.undo));
    await tester.tap(find.byIcon(Icons.delete), warnIfMissed: false);
    await settle(tester);
    expect(pressed, ['redo', 'undo']);
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(420, 330), ratio: 2);
      await tester.pumpWidget(scene(
        dark: dark,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                GlassCheckbox(value: false, onChanged: (_) {}),
                GlassCheckbox(value: true, onChanged: (_) {}),
                GlassCheckbox(value: null, tristate: true, onChanged: (_) {}),
                GlassRadio<int>(value: 0, groupValue: 1, onChanged: (_) {}),
                GlassRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
                GlassStepper(value: 3, onChanged: (_) {}),
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                GlassChip(label: const Text('All'), selected: true, onSelected: (_) {}),
                GlassChip(label: const Text('Photos'), icon: const Icon(Icons.photo_outlined), onSelected: (_) {}),
                GlassChip(label: const Text('Travel'), onSelected: (_) {}, onDeleted: () {}),
              ]),
              const SizedBox(height: 18),
              const Row(children: [
                Expanded(child: GlassProgressBar(value: 0.62)),
                SizedBox(width: 16),
                GlassActivityIndicator(animating: false),
                SizedBox(width: 16),
                GlassProgressRing(value: 0.7),
              ]),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                const GlassPageIndicator(count: 5, page: 1.4),
                const GlassBadge(label: '12', child: Icon(Icons.mail_outline, size: 30, color: Colors.grey)),
                GlassButtonGroup(children: [
                  GlassButtonGroupItem(icon: const Icon(Icons.format_bold), selected: true, onPressed: () {}),
                  GlassButtonGroupItem(icon: const Icon(Icons.format_italic), onPressed: () {}),
                  GlassButtonGroupItem(icon: const Icon(Icons.format_underline), onPressed: () {}),
                ]),
              ]),
            ],
          ),
        ),
      ));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/controls_${dark ? 'dark' : 'light'}.png'));
    });
  }
}

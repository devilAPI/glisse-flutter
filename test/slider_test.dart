import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

import 'helpers.dart';

Widget _slider(double Function() get, void Function(double) set, {int? divisions, bool enabled = true}) {
  return SizedBox(
    width: 236,
    child: StatefulBuilder(
      builder:
          (context, setState) => GlassSlider(
            value: get(),
            divisions: divisions,
            onChanged: enabled ? (v) => setState(() => set(v)) : null,
          ),
    ),
  );
}

void main() {
  testWidgets('dragging changes the value', (tester) async {
    await setUpGlass(tester);
    var value = 0.0;
    var started = 0;
    var ended = 0;
    await tester.pumpWidget(
      scene(
        SizedBox(
          width: 236,
          child: StatefulBuilder(
            builder:
                (context, setState) => GlassSlider(
                  value: value,
                  onChangeStart: (_) => started++,
                  onChangeEnd: (_) => ended++,
                  onChanged: (v) => setState(() => value = v),
                ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(GlassSlider));
    // The thumb's centre travels from 18px in: 200px of travel.
    final gesture = await tester.startGesture(Offset(box.left + 18, box.center.dy));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    expect(value, closeTo(0.5, 0.01));
    await gesture.up();
    await settle(tester);
    expect(started, 1);
    expect(ended, 1);
  });

  testWidgets('tapping jumps to the pointer', (tester) async {
    await setUpGlass(tester);
    var value = 0.0;
    await tester.pumpWidget(scene(_slider(() => value, (v) => value = v)));
    final box = tester.getRect(find.byType(GlassSlider));
    await tester.tapAt(Offset(box.left + 18 + 150, box.center.dy));
    await settle(tester);
    expect(value, closeTo(0.75, 0.01));
  });

  testWidgets('snaps to divisions', (tester) async {
    await setUpGlass(tester);
    var value = 0.0;
    await tester.pumpWidget(scene(_slider(() => value, (v) => value = v, divisions: 4)));
    final box = tester.getRect(find.byType(GlassSlider));
    await tester.tapAt(Offset(box.left + 18 + 90, box.center.dy));
    await settle(tester);
    expect(value, 0.5);
  });

  testWidgets('disabled ignores input', (tester) async {
    await setUpGlass(tester);
    var value = 0.2;
    await tester.pumpWidget(scene(_slider(() => value, (v) => value = v, enabled: false)));
    await tester.tap(find.byType(GlassSlider), warnIfMissed: false);
    await tester.drag(find.byType(GlassSlider), const Offset(80, 0), warnIfMissed: false);
    await settle(tester);
    expect(value, 0.2);
  });

  testWidgets('arrow keys step', (tester) async {
    await setUpGlass(tester);
    var value = 0.5;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      scene(
        SizedBox(
          width: 236,
          child: StatefulBuilder(
            builder:
                (context, setState) =>
                    GlassSlider(value: value, focusNode: focus, onChanged: (v) => setState(() => value = v)),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, closeTo(0.55, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(value, closeTo(0.45, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(value, 1);
  });

  testWidgets('has slider semantics', (tester) async {
    await setUpGlass(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      scene(SizedBox(width: 236, child: GlassSlider(value: 0.3, onChanged: (_) {}, semanticLabel: 'Volume'))),
    );
    expect(
      tester.getSemantics(find.byType(GlassSlider)),
      containsSemantics(
        label: 'Volume',
        value: '30%',
        increasedValue: '35%',
        decreasedValue: '25%',
        isSlider: true,
        isEnabled: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(300, 220), ratio: 3);
      var held = 0.35;
      await tester.pumpWidget(
        scene(
          dark: dark,
          SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassSlider(value: 0, onChanged: (_) {}),
                const SizedBox(height: 8),
                GlassSlider(value: 0.6, onChanged: (_) {}),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder:
                      (context, setState) =>
                          GlassSlider(key: const Key('held'), value: held, onChanged: (v) => setState(() => held = v)),
                ),
                const SizedBox(height: 8),
                const GlassSlider(value: 0.8, onChanged: null),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      final box = tester.getRect(find.byKey(const Key('held')));
      final gesture = await tester.startGesture(Offset(box.left + 18 + (box.width - 36) * 0.35, box.center.dy));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(10, 0));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/slider_${dark ? 'dark' : 'light'}.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

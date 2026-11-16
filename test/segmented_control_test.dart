import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

const _segments = [
  GlassSegment(value: 'day', label: 'Day'),
  GlassSegment(value: 'week', label: 'Week'),
  GlassSegment(value: 'month', label: 'Month'),
];

Widget _control({String? initial = 'day', void Function(String)? onChanged, bool enabled = true}) {
  var value = initial;
  return StatefulBuilder(
    builder: (context, setState) => GlassSegmentedControl<String>(
      segments: _segments,
      value: value,
      onChanged: enabled
          ? (v) {
              setState(() => value = v);
              onChanged?.call(v);
            }
          : null,
    ),
  );
}

void main() {
  testWidgets('is sized as iOS: 84 by 32 a segment', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(_control()));
    expect(tester.getSize(find.byType(GlassSegmentedControl<String>)), const Size(252, 32));
  });

  testWidgets('tapping a segment selects it', (tester) async {
    await setUpGlass(tester);
    final chosen = <String>[];
    await tester.pumpWidget(scene(_control(onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassSegmentedControl<String>));
    await tester.tapAt(Offset(box.left + 84 * 2.5, box.center.dy));
    await settle(tester);
    expect(chosen, ['month']);
  });

  testWidgets('dragging the thumb selects where it lands', (tester) async {
    await setUpGlass(tester);
    final chosen = <String>[];
    await tester.pumpWidget(scene(_control(onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassSegmentedControl<String>));
    final gesture = await tester.startGesture(Offset(box.left + 42, box.center.dy));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(9, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    expect(chosen, ['week']);
  });

  testWidgets('a tap released far below the bar does not count', (tester) async {
    await setUpGlass(tester);
    final chosen = <String>[];
    await tester.pumpWidget(scene(_control(onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassSegmentedControl<String>));
    final gesture = await tester.startGesture(Offset(box.left + 84 * 1.5, box.center.dy));
    await gesture.moveBy(const Offset(0, 100));
    await gesture.up();
    await settle(tester);
    expect(chosen, isEmpty);
  });

  testWidgets('arrow keys move the selection', (tester) async {
    await setUpGlass(tester);
    final chosen = <String>[];
    await tester.pumpWidget(scene(_control(onChanged: chosen.add)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    expect(chosen, ['week', 'month', 'day']);
  });

  testWidgets('disabled ignores taps', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(_control(enabled: false)));
    final box = tester.getRect(find.byType(GlassSegmentedControl<String>));
    await tester.tapAt(Offset(box.left + 84 * 2.5, box.center.dy));
    await settle(tester);
  });

  testWidgets('semantics mark the checked segment', (tester) async {
    await setUpGlass(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(scene(_control(initial: 'week')));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Week')),
      matchesSemantics(
        label: 'Week',
        isChecked: true,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('follows a value changed from outside', (tester) async {
    await setUpGlass(tester);
    Widget build(String v) => scene(GlassSegmentedControl<String>(segments: _segments, value: v, onChanged: (_) {}));
    await tester.pumpWidget(build('day'));
    await tester.pumpWidget(build('month'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await settle(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(320, 150), ratio: 3);
      await tester.pumpWidget(scene(
        dark: dark,
        Column(mainAxisSize: MainAxisSize.min, children: [
          GlassSegmentedControl<String>(segments: _segments, value: 'week', onChanged: (_) {}),
          const SizedBox(height: 28),
          GlassSegmentedControl<String>(key: const Key('held'), segments: _segments, value: 'day', onChanged: (_) {}),
        ]),
      ));
      await settle(tester);
      final box = tester.getRect(find.byKey(const Key('held')));
      final gesture = await tester.startGesture(Offset(box.left + 42, box.center.dy));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/segmented_${dark ? 'dark' : 'light'}.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

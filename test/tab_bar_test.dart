import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

import 'helpers.dart';

const _tabs = [
  GlassSegment(value: 0, label: 'Home'),
  GlassSegment(value: 1, label: 'Browse'),
  GlassSegment(value: 2, label: 'Radio'),
  GlassSegment(value: 3, label: 'Library'),
];

const _iconTabs = [
  GlassSegment(value: 0, label: 'Home', icon: Icons.home_rounded),
  GlassSegment(value: 1, label: 'Browse', icon: Icons.grid_view_rounded),
  GlassSegment(value: 2, label: 'Radio', icon: Icons.radio),
  GlassSegment(value: 3, label: 'Library', icon: Icons.library_music),
];

Widget _bar({List<GlassSegment<int>> items = _tabs, int? initial = 0, void Function(int)? onChanged, Key? key}) {
  var value = initial;
  return StatefulBuilder(
    builder:
        (context, setState) => GlassTabBar<int>(
          key: key,
          items: items,
          value: value,
          onChanged: (v) {
            setState(() => value = v);
            onChanged?.call(v);
          },
        ),
  );
}

void main() {
  testWidgets('is sized as Glisse: 84 by 32 a tab, inset 4', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(_bar()));
    expect(tester.getSize(find.byType(GlassTabBar<int>)), const Size(4 * 84 + 8, 40));
  });

  testWidgets('with icons, tabs are 72 by 52', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(_bar(items: _iconTabs)));
    expect(tester.getSize(find.byType(GlassTabBar<int>)), const Size(4 * 72 + 8, 60));
  });

  testWidgets('tapping a tab selects it', (tester) async {
    await setUpGlass(tester, size: const Size(500, 300));
    final chosen = <int>[];
    await tester.pumpWidget(scene(_bar(onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassTabBar<int>));
    await tester.tapAt(Offset(box.left + 4 + 84 * 2.5, box.center.dy));
    await settle(tester);
    expect(chosen, [2]);
  });

  testWidgets('a drag carries the selection and selects where it is let go', (tester) async {
    await setUpGlass(tester, size: const Size(500, 300));
    final chosen = <int>[];
    await tester.pumpWidget(scene(_bar(onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassTabBar<int>));
    final gesture = await tester.startGesture(Offset(box.left + 4 + 42, box.center.dy));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(13, 3));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    expect(chosen, [3]);
  });

  testWidgets('a drag stays within the bar', (tester) async {
    await setUpGlass(tester, size: const Size(500, 300));
    final chosen = <int>[];
    await tester.pumpWidget(scene(_bar(initial: 2, onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassTabBar<int>));
    final gesture = await tester.startGesture(Offset(box.left + 4 + 84 * 2.5, box.center.dy));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    expect(chosen, [0]);
  });

  testWidgets('a value of null hides the selection, and a tap shows it', (tester) async {
    await setUpGlass(tester, size: const Size(500, 300));
    final chosen = <int>[];
    await tester.pumpWidget(scene(_bar(initial: null, onChanged: chosen.add)));
    final box = tester.getRect(find.byType(GlassTabBar<int>));
    await tester.tapAt(Offset(box.left + 4 + 84 * 1.5, box.center.dy));
    await settle(tester);
    expect(chosen, [1]);
  });

  testWidgets('semantics mark the selected tab', (tester) async {
    await setUpGlass(tester, size: const Size(500, 300));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(scene(_bar(initial: 1)));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Browse')),
      matchesSemantics(
        label: 'Browse',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(400, 260), ratio: 3);
      await tester.pumpWidget(
        scene(
          dark: dark,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bar(initial: 1),
              const SizedBox(height: 24),
              _bar(items: _iconTabs, initial: 0),
              const SizedBox(height: 30),
              _bar(key: const Key('held'), initial: 0),
            ],
          ),
        ),
      );
      await settle(tester);
      final box = tester.getRect(find.byKey(const Key('held')));
      final gesture = await tester.startGesture(Offset(box.left + 4 + 42, box.center.dy));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tab_bar_${dark ? 'dark' : 'light'}.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

void main() {
  testWidgets('tapping toggles', (tester) async {
    await setUpGlass(tester);
    var value = false;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder: (context, setState) => GlassSwitch(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    await tester.tap(find.byType(GlassSwitch));
    await settle(tester);
    expect(value, isTrue);
    await tester.tap(find.byType(GlassSwitch));
    await settle(tester);
    expect(value, isFalse);
  });

  testWidgets('dragging across turns it on', (tester) async {
    await setUpGlass(tester);
    var value = false;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder: (context, setState) => GlassSwitch(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    await tester.drag(find.byType(GlassSwitch), const Offset(40, 0));
    await settle(tester);
    expect(value, isTrue);
  });

  testWidgets('a short drag past halfway flips it, as in Glisse', (tester) async {
    await setUpGlass(tester);
    var value = false;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder: (context, setState) => GlassSwitch(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    // The thumb travels 21.7px; 14px is past halfway.
    final gesture = await tester.startGesture(tester.getCenter(find.byType(GlassSwitch)));
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    expect(value, isTrue);
  });

  testWidgets('a quick vertical swipe settles the thumb', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(
      scene(
        ListView(
          children: [
            const SizedBox(height: 100),
            Center(child: GlassSwitch(value: false, onChanged: (_) {})),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(GlassSwitch)));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -30));
    await settle(tester);
    final state = tester.state(find.byType(GlassSwitch));
    expect((state as dynamic).debugLift as double, lessThan(0.01));
    await gesture.up();
    await settle(tester);
  });

  testWidgets('a scroll that starts on the switch, a little sideways, scrolls', (tester) async {
    await setUpGlass(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var value = false;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder:
              (context, setState) => ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 100),
                  Center(child: GlassSwitch(value: value, onChanged: (v) => setState(() => value = v))),
                  const SizedBox(height: 2000),
                ],
              ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(GlassSwitch)));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(3, -8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    expect(controller.offset, greaterThan(0));
    expect(value, isFalse);
  });

  testWidgets('a tap with a little drift still toggles', (tester) async {
    await setUpGlass(tester);
    var value = false;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder: (context, setState) => GlassSwitch(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(GlassSwitch)));
    await gesture.moveBy(const Offset(0, 3));
    await gesture.moveBy(const Offset(0, 3));
    await gesture.up();
    await settle(tester);
    expect(value, isTrue);
  });

  testWidgets('a short sideways move lands where it is let go', (tester) async {
    await setUpGlass(tester);
    var value = false;
    var changes = 0;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder:
              (context, setState) => GlassSwitch(
                value: value,
                onChanged:
                    (v) => setState(() {
                      value = v;
                      changes++;
                    }),
              ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(GlassSwitch)));
    await gesture.moveBy(const Offset(6, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await settle(tester);
    // 6px of a 21.7px travel is short of halfway: no change, and no tap.
    expect(value, isFalse);
    expect(changes, 0);
    // And a tap afterwards still toggles.
    await tester.tap(find.byType(GlassSwitch));
    await settle(tester);
    expect(value, isTrue);
  });

  testWidgets('disabled ignores taps', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(const GlassSwitch(value: false, onChanged: null)));
    await tester.tap(find.byType(GlassSwitch), warnIfMissed: false);
    await settle(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(240, 100), ratio: 3);
      await tester.pumpWidget(
        scene(
          dark: dark,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GlassSwitch(value: false, onChanged: (_) {}),
              GlassSwitch(value: true, onChanged: (_) {}),
              GlassSwitch(key: const Key('held'), value: true, onChanged: (_) {}),
            ],
          ),
        ),
      );
      await settle(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('held'))));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/switch_${dark ? 'dark' : 'light'}.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

void main() {
  testWidgets('tapping toggles', (tester) async {
    await setUpGlass(tester);
    var value = false;
    await tester.pumpWidget(scene(StatefulBuilder(
      builder: (context, setState) => GlassSwitch(value: value, onChanged: (v) => setState(() => value = v)),
    )));
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
    await tester.pumpWidget(scene(StatefulBuilder(
      builder: (context, setState) => GlassSwitch(value: value, onChanged: (v) => setState(() => value = v)),
    )));
    await tester.drag(find.byType(GlassSwitch), const Offset(40, 0));
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
      await tester.pumpWidget(scene(
        dark: dark,
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          GlassSwitch(value: false, onChanged: (_) {}),
          GlassSwitch(value: true, onChanged: (_) {}),
          GlassSwitch(key: const Key('held'), value: true, onChanged: (_) {}),
        ]),
      ));
      await settle(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('held'))));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/switch_${dark ? 'dark' : 'light'}.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

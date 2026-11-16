import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

import 'helpers.dart';

void main() {
  testWidgets('calls onPressed', (tester) async {
    await setUpGlass(tester);
    var count = 0;
    await tester.pumpWidget(scene(GlassButton(onPressed: () => count++, child: const Text('Go'))));
    await tester.tap(find.text('Go'));
    await settle(tester);
    expect(count, 1);
  });

  testWidgets('disabled does nothing', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(const GlassButton(onPressed: null, child: Text('Go'))));
    await tester.tap(find.text('Go'), warnIfMissed: false);
    await settle(tester);
  });

  testWidgets('icon-only is a circle', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(GlassButton(onPressed: () {}, icon: const Icon(Icons.add), semanticLabel: 'Add')));
    final size = tester.getSize(find.byType(LiquidGlassBox));
    expect(size, const Size(40, 40));
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(420, 160), ratio: 2);
      await tester.pumpWidget(
        scene(
          dark: dark,
          Wrap(
            spacing: 10,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              GlassButton(onPressed: () {}, child: const Text('Glass')),
              GlassButton(onPressed: () {}, variant: GlassButtonVariant.filled, child: const Text('Continue')),
              GlassButton(
                onPressed: () {},
                destructive: true,
                icon: const Icon(Icons.delete_outline),
                child: const Text('Delete'),
              ),
              GlassButton(onPressed: () {}, icon: const Icon(Icons.share), semanticLabel: 'Share'),
              const GlassButton(onPressed: null, child: Text('Disabled')),
              GlassButton(key: const Key('held'), onPressed: () {}, tint: Colors.purple, child: const Text('Held')),
            ],
          ),
        ),
      );
      await settle(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('held'))));
      await gesture.moveBy(const Offset(12, 4));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/button_${dark ? 'dark' : 'light'}.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

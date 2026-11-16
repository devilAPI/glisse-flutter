import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

void main() {
  testWidgets('the loupe shows what is under the finger', (tester) async {
    await setUpGlass(tester, size: const Size(400, 300));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: GlassBackdrop(
            background: ColoredBox(
              color: const Color(0xFFFFF7E0),
              child: Column(
                children: [
                  for (var i = 0; i < 10; i++)
                    SizedBox(
                      height: 30,
                      child: Text(
                        'Line $i of the text under the loupe',
                        style: TextStyle(fontSize: 18, color: Colors.primaries[i % 12]),
                      ),
                    ),
                ],
              ),
            ),
            child: const GlassLoupeRegion(child: SizedBox.expand()),
          ),
        ),
      ),
    );
    // Long-press over "Line 6".
    final gesture = await tester.startGesture(const Offset(120, 195));
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.byType(LiquidGlassBox), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/loupe.png'));
    await gesture.up();
    await settle(tester);
  });
}

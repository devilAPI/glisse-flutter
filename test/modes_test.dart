import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

void main() {
  for (final mode in [GlassMode.frost, GlassMode.auto]) {
    testWidgets('glass without a backdrop, ${mode.name}', (tester) async {
      await setUpGlass(tester, size: const Size(400, 200));
      await tester.pumpWidget(scene(backdrop: false, Glass(width: 260, height: 120, borderRadius: 40, mode: mode)));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/mode_${mode.name}.png'));
    });
  }
}

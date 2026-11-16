import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'smoke_test.dart' show everything;

void main() {
  testWidgets('every tappable widget has a label', (tester) async {
    await setUpGlass(tester, size: const Size(900, 1400), ratio: 1);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      scene(SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: everything()))),
    );
    await settle(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}

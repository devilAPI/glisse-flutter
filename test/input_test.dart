import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

void main() {
  testWidgets('typing reports changes', (tester) async {
    await setUpGlass(tester);
    String? last;
    await tester.pumpWidget(scene(SizedBox(width: 300, child: GlassInput(placeholder: 'Name', onChanged: (v) => last = v))));
    await tester.enterText(find.byType(EditableText), 'Ada');
    await settle(tester);
    expect(last, 'Ada');
  });

  testWidgets('search field clears', (tester) async {
    await setUpGlass(tester);
    final controller = TextEditingController(text: 'liquid');
    addTearDown(controller.dispose);
    await tester.pumpWidget(scene(SizedBox(width: 300, child: GlassSearchField(controller: controller))));
    await settle(tester);
    expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Clear'));
    await settle(tester);
    expect(controller.text, isEmpty);
    expect(find.bySemanticsLabel('Clear'), findsNothing);
  });

  testWidgets('disabled cannot be edited', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(const SizedBox(width: 300, child: GlassInput(enabled: false, placeholder: 'Off'))));
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.readOnly || !(field.focusNode.canRequestFocus), isTrue);
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(400, 180));
      final controller = TextEditingController(text: 'Liquid glass');
      addTearDown(controller.dispose);
      await tester.pumpWidget(scene(
        dark: dark,
        SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const GlassInput(placeholder: 'Email', icon: Icon(Icons.mail_outline)),
            const SizedBox(height: 12),
            GlassSearchField(controller: controller),
            const SizedBox(height: 12),
            const GlassSearchField(),
          ]),
        ),
      ));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/input_${dark ? 'dark' : 'light'}.png'));
    });
  }
}

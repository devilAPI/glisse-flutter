// Drives the real gallery on a device or desktop:
//   flutter test integration_test -d linux
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';
import 'package:glisse_example/main.dart' as app;
import 'package:integration_test/integration_test.dart';

Future<void> frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  // The gallery's own list, which holds every section.
  final list = find.byWidgetPredicate((w) => w is ListView && w.controller != null).first;
  final screen = tester.getRect(find.byType(MaterialApp));
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) {
      final at = tester.getRect(finder.first);
      if (at.top > screen.top + 80 && at.bottom < screen.bottom - 120) break;
      if (at.top <= screen.top + 80) {
        await tester.drag(list, const Offset(0, 200));
        await frames(tester, 10);
        continue;
      }
    }
    await tester.drag(list, const Offset(0, -200));
    await frames(tester, 10);
  }
  await frames(tester, 10);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the gallery takes a tour without errors', (tester) async {
    final semantics = tester.ensureSemantics();
    app.main();
    await frames(tester, 60);
    expect(GlassShaders.program, isNotNull);

    // Buttons.
    await tester.tap(find.text('Continue'));
    await frames(tester);
    expect(find.text('Last action: Continue'), findsOneWidget);

    // Switches: tap and drag.
    await reveal(tester, find.text('Bluetooth'));
    final switches = find.byType(GlassSwitch);
    await tester.tap(switches.at(1));
    await frames(tester);
    await tester.drag(switches.at(2), const Offset(30, 0));
    await frames(tester);

    // Slider drag.
    await reveal(tester, find.byType(GlassSlider).first);
    await tester.drag(find.byType(GlassSlider).first, const Offset(-60, 0));
    await frames(tester);

    // Segmented control and tab bar.
    await reveal(tester, find.bySemanticsLabel('Month'));
    await tester.tap(find.bySemanticsLabel('Month'), warnIfMissed: false);
    await frames(tester);
    await tester.tap(find.bySemanticsLabel('Radio').first, warnIfMissed: false);
    await frames(tester);

    // Every overlay.
    await reveal(tester, find.text('Alert'));
    await tester.tap(find.text('Alert'));
    await frames(tester);
    await tester.tap(find.text('Cancel'));
    await frames(tester);
    await tester.tap(find.text('Sheet'));
    await frames(tester);
    await tester.tap(find.text('Save for later'));
    await frames(tester);
    await tester.tap(find.text('Toast'));
    await frames(tester, 10);
    await tester.tap(find.text('Popover'), warnIfMissed: false);
    await frames(tester);
    await tester.tapAt(const Offset(5, 300));
    await frames(tester);

    // The menu.
    // The top bar's menu, not the navigation section's own "More" button.
    final menus = find.byType(GlassMenu).evaluate().toList();
    final top = menus.firstWhere((e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy < 80);
    await tester.tap(find.byElementPredicate((e) => e == top));
    await frames(tester);
    await tester.tap(find.text('Pause wallpaper'));
    await frames(tester);

    // The theme toggle, and back.
    await tester.tap(find.bySemanticsLabel('Toggle theme'));
    await frames(tester);
    await tester.tap(find.bySemanticsLabel('Toggle theme'));
    await frames(tester);

    // The playground's modes.
    await reveal(tester, find.bySemanticsLabel('Frost').last);
    for (final mode in ['Frost', 'Live', 'Captured', 'Auto']) {
      await tester.tap(find.bySemanticsLabel(mode).last, warnIfMissed: false);
      await frames(tester);
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

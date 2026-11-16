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
  // Scrolls the gallery's list rather than dragging it: a drag from the
  // list's middle may land on a wheel or a knob, which keep it.
  final list = find.byWidgetPredicate((w) => w is ListView && w.controller != null).first;
  final controller = (tester.widget(list) as ListView).controller!;
  final screen = tester.getRect(find.byType(MaterialApp));
  for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
    controller.jumpTo((controller.offset + 300).clamp(0.0, controller.position.maxScrollExtent));
    await frames(tester, 2);
  }
  final element = finder.evaluate().first;
  await Scrollable.ensureVisible(element, alignment: 0.4);
  await frames(tester, 10);
  final at = tester.getRect(finder.first);
  expect(at.top > screen.top && at.bottom < screen.bottom, isTrue, reason: 'revealed at $at');
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
    await reveal(tester, find.bySemanticsLabel('Month').first);
    await tester.tap(find.bySemanticsLabel('Month').first, warnIfMissed: false);
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

    // Pickers: the range slider, a wheel and the rating.
    await reveal(tester, find.byType(GlassRangeSlider).first);
    await tester.drag(find.byType(GlassRangeSlider).first, const Offset(-40, 0));
    await frames(tester);
    await reveal(tester, find.byType(GlassPicker).first);
    await tester.drag(find.byType(GlassPicker).first, const Offset(0, -64));
    await frames(tester, 60);
    await reveal(tester, find.byType(GlassRating).first);
    await tester.tap(find.byType(GlassRating).first);
    await frames(tester);

    // Surfaces: the action sheet, a banner, the context menu and a disclosure.
    await reveal(tester, find.text('Action sheet'));
    await tester.tap(find.text('Action sheet'));
    await frames(tester);
    await tester.tap(find.text('Cancel').last);
    await frames(tester);
    await tester.tap(find.text('Banner'));
    await frames(tester);
    await tester.longPress(find.text('Sunset'));
    await frames(tester);
    await tester.tap(find.text('Copy').last);
    await frames(tester);
    await reveal(tester, find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    await frames(tester);

    // Extras: slide to pay, a swatch, a knob and the calendar.
    await reveal(tester, find.byType(GlassSlideToConfirm).first);
    final knob = tester.getRect(find.byType(GlassSlideToConfirm).first);
    await tester.dragFrom(Offset(knob.left + 28, knob.center.dy), Offset(knob.width, 0));
    await frames(tester);
    await reveal(tester, find.byType(GlassColorSwatches).first);
    await tester.tapAt(tester.getTopLeft(find.byType(GlassColorSwatches).first) + const Offset(20, 14));
    await frames(tester);
    await reveal(tester, find.byType(GlassKnob).first);
    await tester.drag(find.byType(GlassKnob).first, const Offset(0, -40));
    await frames(tester);
    await reveal(tester, find.byType(GlassCalendar).first);
    await tester.tap(find.bySemanticsLabel('Next month'), warnIfMissed: false);
    await frames(tester);

    // The lenses over the whole page: drag the magnifier far, and a loupe
    // over the wallpaper beside the content.
    final pageLens = find.byWidgetPredicate((w) => w is GlassSwitch && w.semanticLabel == 'Lenses over the whole page');
    await reveal(tester, pageLens);
    await tester.tap(pageLens);
    await frames(tester);
    await tester.drag(find.byType(GlassMagnifier).last, const Offset(-300, -200));
    await frames(tester);
    await tester.longPressAt(const Offset(60, 400));
    await frames(tester);
    await tester.tap(pageLens);
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

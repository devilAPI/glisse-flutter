// Bugs found in review, kept fixed.
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

final GlobalKey shot = GlobalKey();

Widget scrollingApp(Key key, ScrollController c) => MaterialApp(
      home: RepaintBoundary(
        key: shot,
        child: Material(
          child: GlassBackdrop(
            key: key,
            background: const Stripes(),
            child: ListView(controller: c, children: [
              const SizedBox(height: 100),
              const Glass(height: 80, bend: 1, child: SizedBox(width: 200, height: 80)),
              const SizedBox(height: 2000),
            ]),
          ),
        ),
      ),
    );

Future<List<int>> grab(WidgetTester tester) async {
  final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  });
  return bytes!;
}

void main() {
  testWidgets('glass inside a backdrop\'s background settles instead of copying itself', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Material(
        child: GlassBackdrop(
          background: Stack(children: [
            Positioned.fill(child: Stripes()),
            Center(child: Glass(width: 100, height: 60)),
          ]),
          child: SizedBox.expand(),
        ),
      ),
    ));
    var frames = 0;
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) break;
      frames++;
    }
    expect(frames, lessThan(20));
  });

  testWidgets('a popover survives its parent rebuilding while open', (tester) async {
    await setUpGlass(tester);
    var n = 0;
    late StateSetter set;
    await tester.pumpWidget(scene(StatefulBuilder(builder: (context, s) {
      set = s;
      return GlassPopover(
        popoverBuilder: (_) => Text('Card $n'),
        child: const Text('Anchor'),
      );
    })));
    await tester.tap(find.text('Anchor'));
    await settle(tester);
    expect(find.text('Card 0'), findsOneWidget);
    set(() => n = 1);
    await tester.pump();
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets('a tooltip goes after a cancelled long press', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(scene(const GlassTooltip(message: 'Tip', child: Text('Hold me'))));
    final g = await tester.startGesture(tester.getCenter(find.text('Hold me')));
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.text('Tip'), findsOneWidget);
    await g.cancel();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Tip'), findsNothing);
  });

  testWidgets('glass that scrolls refracts as if laid out there', (tester) async {
    await setUpGlass(tester, size: const Size(400, 600), ratio: 1);
    final c1 = ScrollController();
    await tester.pumpWidget(scrollingApp(const ValueKey(1), c1));
    await settle(tester);
    c1.jumpTo(60);
    await settle(tester);
    final scrolled = await grab(tester);

    final c2 = ScrollController(initialScrollOffset: 60);
    await tester.pumpWidget(scrollingApp(const ValueKey(2), c2));
    await settle(tester);
    final fresh = await grab(tester);
    var diff = 0;
    for (var i = 0; i < scrolled.length; i++) {
      if ((scrolled[i] - fresh[i]).abs() > 8) diff++;
    }
    expect(diff, 0);
  });

  testWidgets('HitPadding round an empty child takes no hits and does not throw', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: HitPadding(padding: EdgeInsets.all(10), child: SizedBox.shrink())),
    ));
    await tester.tapAt(tester.getCenter(find.byType(HitPadding)) + const Offset(3, 3));
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets('RTL segments: semantics match the drawn labels', (tester) async {
    await setUpGlass(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          child: Center(
            child: GlassSegmentedControl<int>(
              segments: const [
                GlassSegment(value: 0, label: 'First'),
                GlassSegment(value: 1, label: 'Second'),
                GlassSegment(value: 2, label: 'Third'),
              ],
              value: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ));
    final bar = tester.getRect(find.byType(GlassSegmentedControl<int>));
    final first = tester.getRect(find.bySemanticsLabel('First'));
    // The painter and pointer code put index 0 at the left.
    expect(first.left, lessThan(bar.left + 84));
    handle.dispose();
  });

  testWidgets('the magnifier keeps every move, even two in one frame', (tester) async {
    await setUpGlass(tester);
    final moves = <Offset>[];
    await tester.pumpWidget(scene(SizedBox(
      width: 400,
      height: 300,
      child: GlassMagnifier(size: 60, position: null, onMoved: moves.add),
    )));
    final start = tester.getCenter(find.bySemanticsLabel('Magnifier'));
    final g = await tester.startGesture(start, kind: PointerDeviceKind.touch);
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    final at0 = moves.last;
    // Two events, no frame between.
    await g.moveBy(const Offset(10, 0));
    await g.moveBy(const Offset(10, 0));
    await tester.pump();
    await g.up();
    expect(moves.last.dx - at0.dx, 20);
  });

  testWidgets('a popover mounted with an open controller shows its card', (tester) async {
    await setUpGlass(tester);
    final c = GlassPopoverController()..show();
    await tester.pumpWidget(scene(GlassPopover(
      controller: c,
      popoverBuilder: (_) => const Text('Card'),
      child: const Text('Anchor'),
    )));
    await settle(tester);
    expect(find.text('Card'), findsOneWidget);
  });

  testWidgets('a tab bar emptied mid-press does not throw', (tester) async {
    await setUpGlass(tester);
    var items = const [GlassSegment(value: 0, label: 'A'), GlassSegment(value: 1, label: 'B')];
    late StateSetter set;
    await tester.pumpWidget(scene(StatefulBuilder(builder: (context, s) {
      set = s;
      return GlassTabBar<int>(items: items, value: 0, onChanged: (_) {});
    })));
    final g = await tester.startGesture(tester.getCenter(find.byType(GlassTabBar<int>)));
    await tester.pump();
    set(() => items = const []);
    await tester.pump();
    await g.moveBy(const Offset(20, 0));
    await g.up();
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets('RTL dock: hovering an icon labels that icon', (tester) async {
    await setUpGlass(tester);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          child: Center(
            child: GlassDock(items: [
              GlassDockItem(icon: const ColoredBox(color: Colors.red), label: 'Zero', onPressed: () {}),
              GlassDockItem(icon: const ColoredBox(color: Colors.green), label: 'One', onPressed: () {}),
              GlassDockItem(icon: const ColoredBox(color: Colors.blue), label: 'Two', onPressed: () {}),
            ]),
          ),
        ),
      ),
    ));
    final dock = tester.getRect(find.byType(GlassDock));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(dock.left + 8 + 24, dock.bottom - 20));
    await mouse.moveTo(Offset(dock.left + 8 + 24, dock.bottom - 20));
    await settle(tester);
    final shown = ['Zero', 'One', 'Two'].where((l) => find.text(l).evaluate().isNotEmpty).toList();
    final pressed = <String>[];
    await mouse.removePointer();
    // The dock is laid out left to right, as it magnifies.
    expect(shown, ['Zero'], reason: pressed.join());
  });

  testWidgets('RTL input: the clear button hangs into the padding at the end', (tester) async {
    await setUpGlass(tester);
    final controller = TextEditingController(text: 'glass');
    addTearDown(controller.dispose);
    await tester.pumpWidget(scene(Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(width: 300, child: GlassSearchField(controller: controller)),
    )));
    await settle(tester);
    final field = tester.getRect(find.byType(GlassSearchField));
    final clear = tester.getRect(find.bySemanticsLabel('Clear'));
    expect(clear.left - field.left, closeTo(6, 0.5));
  });

  testWidgets('a list scrolls under a glass bar, and the glass sees it move', (tester) async {
    await setUpGlass(tester, size: const Size(400, 600));
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late GlassBackdropController backdrop;
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: GlassBackdrop(
          background: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemBuilder: (context, i) => SizedBox(
              height: 60,
              child: ColoredBox(color: Colors.primaries[i % 12], child: Text('Row $i')),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Builder(builder: (context) {
              backdrop = GlassBackdrop.maybeOf(context)!;
              return GlassTabBar<int>(
                items: const [GlassSegment(value: 0, label: 'One'), GlassSegment(value: 1, label: 'Two')],
                value: 0,
                onChanged: (_) {},
              );
            }),
          ),
        ),
      ),
    ));
    await settle(tester);
    final before = backdrop.image;
    expect(before, isNotNull);
    // A drag on the list, above the bar, reaches it through the backdrop.
    await tester.drag(find.text('Row 2'), const Offset(0, -300));
    await settle(tester);
    expect(controller.offset, greaterThan(0));
    // The list scrolled inside its own repaint boundary; the copy followed.
    expect(identical(backdrop.image, before), isFalse);
  });

  group('second review', () {
    Widget menu({required bool show, required bool enabled, ValueChanged<bool>? onOpenChanged, List<String>? log}) {
      return scene(StatefulBuilder(
        builder: (context, setState) => show
            ? GlassContextMenu(
                enabled: enabled,
                onOpenChanged: onOpenChanged,
                items: [
                  GlassMenuItem(label: const Text('Copy'), onSelected: () => log?.add('copy')),
                  GlassMenuItem(label: const Text('Share'), onSelected: () => log?.add('share')),
                ],
                child: const SizedBox(width: 120, height: 60, child: Center(child: Text('Photo'))),
              )
            : const SizedBox(),
      ));
    }

    testWidgets('a context menu removed while open does not throw or leak', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      var open = false;
      late StateSetter outer;
      var show = true;
      await tester.pumpWidget(scene(StatefulBuilder(builder: (context, setState) {
        outer = setState;
        return show
            ? GlassContextMenu(
                onOpenChanged: (v) => setState(() => open = v),
                items: [GlassMenuItem(label: const Text('Copy'), onSelected: () {})],
                child: const SizedBox(width: 120, height: 60, child: Center(child: Text('Photo'))),
              )
            : const SizedBox();
      })));
      await tester.tap(find.text('Photo'), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await settle(tester);
      expect(open, isTrue);
      outer(() => show = false);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('disabling a held context menu or disclosure does not throw', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(menu(show: true, enabled: true));
      final press = await tester.startGesture(tester.getCenter(find.text('Photo')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(menu(show: true, enabled: false));
      await press.up();
      await settle(tester);
      expect(tester.takeException(), isNull);

      Widget disclosure(bool enabled) => scene(SizedBox(
            width: 300,
            child: GlassDisclosure(enabled: enabled, title: const Text('More'), child: const Text('Body')),
          ));
      await tester.pumpWidget(disclosure(true));
      final hold = await tester.startGesture(tester.getCenter(find.text('More')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(disclosure(false));
      await hold.up();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a context menu reopened while closing takes the keyboard again', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final log = <String>[];
      await tester.pumpWidget(menu(show: true, enabled: true, log: log));
      await tester.tap(find.text('Photo'), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 32));
      await tester.tap(find.text('Photo').first, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(log, ['copy']);
    });

    testWidgets('rating steps from a fraction to the next grid point', (tester) async {
      await setUpGlass(tester);
      var value = 3.7;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(scene(StatefulBuilder(
        builder: (context, setState) =>
            GlassRating(value: value, focusNode: focus, onChanged: (v) => setState(() => value = v)),
      )));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(value, 4);
      value = 4.3;
      await tester.pumpWidget(scene(StatefulBuilder(
        builder: (context, setState) =>
            GlassRating(value: value, focusNode: focus, onChanged: (v) => setState(() => value = v)),
      )));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      expect(value, 4);
    });

    testWidgets('a spring does not bounce under reduced motion', (tester) async {
      final spring = GlassSpring(vsync: const TestVSync(), value: 0, stiffness: 400, damping: 20)..reduceMotion = true;
      addTearDown(spring.dispose);
      spring.jump(0, velocity: 4);
      expect(spring.value, 0);
      expect(spring.isMoving, isFalse);
    });

    testWidgets('calendar reports the month a new selection brings into view', (tester) async {
      await setUpGlass(tester, size: const Size(400, 500));
      final months = <DateTime>[];
      Widget calendar(DateTime selected) => scene(SizedBox(
            width: 340,
            child: GlassCalendar(
              selectedDate: selected,
              initialMonth: DateTime(2026, 3),
              onDateSelected: (_) {},
              onMonthChanged: months.add,
            ),
          ));
      await tester.pumpWidget(calendar(DateTime(2026, 3, 10)));
      await tester.pumpWidget(calendar(DateTime(2026, 7, 4)));
      await settle(tester);
      expect(months, [DateTime(2026, 7)]);
    });
  });
}

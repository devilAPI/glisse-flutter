import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

import 'helpers.dart';

Widget _rtl(Widget child) => Directionality(textDirection: TextDirection.rtl, child: child);

void main() {
  group('GlassSlideToConfirm', () {
    Finder knob() => find.descendant(of: find.byType(GlassSlideToConfirm), matching: find.byType(GlassPressable));
    Offset knobStart(WidgetTester tester) => tester.getCenter(knob());

    Future<void> pumpSlide(WidgetTester tester, {VoidCallback? onConfirmed, Duration? resetAfter, bool rtl = false}) {
      Widget slide = SizedBox(
        width: 300,
        child: GlassSlideToConfirm(onConfirmed: onConfirmed, resetAfter: resetAfter, confirmedLabel: 'Done'),
      );
      if (rtl) slide = _rtl(slide);
      return tester.pumpWidget(scene(slide));
    }

    testWidgets('slides past the threshold to confirm', (tester) async {
      await setUpGlass(tester);
      var calls = 0;
      await pumpSlide(tester, onConfirmed: () => calls++);
      final from = knobStart(tester);
      // The knob travels 300 - 8 - 48 = 244px; 90% is about 220.
      await tester.dragFrom(from, const Offset(230, 0));
      await settle(tester);
      expect(calls, 1);
      expect(tester.getCenter(knob()).dx, closeTo(from.dx + 244, 0.5));
      expect(find.text('Done'), findsOneWidget);
      // Once confirmed, it doesn't confirm again.
      await tester.dragFrom(tester.getCenter(knob()), const Offset(-230, 0));
      await settle(tester);
      expect(calls, 1);
      expect(tester.getCenter(knob()).dx, closeTo(from.dx + 244, 0.5));
    });

    testWidgets('a short slide follows the finger, then springs back', (tester) async {
      await setUpGlass(tester);
      var calls = 0;
      await pumpSlide(tester, onConfirmed: () => calls++);
      final from = knobStart(tester);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(60, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(tester.getCenter(knob()).dx, closeTo(from.dx + 120, 1));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getCenter(knob()).dx, greaterThan(from.dx + 20));
      await settle(tester);
      expect(calls, 0);
      expect(tester.getCenter(knob()).dx, closeTo(from.dx, 0.5));
    });

    testWidgets('a drag past the end stays at the end', (tester) async {
      await setUpGlass(tester);
      var calls = 0;
      await pumpSlide(tester, onConfirmed: () => calls++);
      final from = knobStart(tester);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      expect(tester.getCenter(knob()).dx, closeTo(from.dx + 244, 0.5));
      await gesture.up();
      await settle(tester);
      expect(calls, 1);
    });

    testWidgets('enter and space confirm from the keyboard; semantics tap too', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      var calls = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        scene(SizedBox(width: 300, child: GlassSlideToConfirm(focusNode: focus, onConfirmed: () => calls++))),
      );
      final node = tester.getSemantics(find.byType(GlassSlideToConfirm));
      expect(node.label, 'Slide to confirm');
      expect(node.flagsCollection.isButton, isTrue);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(calls, 1);

      await tester.pumpWidget(
        scene(SizedBox(width: 300, child: GlassSlideToConfirm(key: const Key('second'), onConfirmed: () => calls++))),
      );
      tester.semantics.tap(find.semantics.byLabel('Slide to confirm'));
      await settle(tester);
      expect(calls, 2);
      handle.dispose();
    });

    testWidgets('resetAfter springs it back, ready again', (tester) async {
      await setUpGlass(tester);
      var calls = 0;
      await pumpSlide(tester, onConfirmed: () => calls++, resetAfter: const Duration(seconds: 1));
      final from = knobStart(tester);
      await tester.dragFrom(from, const Offset(240, 0));
      await settle(tester);
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(tester.getCenter(knob()).dx, closeTo(from.dx, 0.5));
      await tester.dragFrom(from, const Offset(240, 0));
      await settle(tester);
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
    });

    testWidgets('disabled does nothing and is dimmed', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      await pumpSlide(tester);
      final from = knobStart(tester);
      await tester.dragFrom(from, const Offset(240, 0));
      await settle(tester);
      expect(tester.getCenter(knob()).dx, closeTo(from.dx, 0.5));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(GlassSlideToConfirm), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.35);
      final node = tester.getSemantics(find.byType(GlassSlideToConfirm));
      expect(node.flagsCollection.isEnabled, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('right to left, it slides the other way', (tester) async {
      await setUpGlass(tester);
      var calls = 0;
      await pumpSlide(tester, onConfirmed: () => calls++, rtl: true);
      final box = tester.getRect(find.byType(GlassSlideToConfirm));
      final from = knobStart(tester);
      expect(from.dx, closeTo(box.right - 28, 0.5));
      await tester.dragFrom(from, const Offset(230, 0));
      await settle(tester);
      expect(calls, 0);
      await tester.dragFrom(from, const Offset(-230, 0));
      await settle(tester);
      expect(calls, 1);
      expect(tester.getCenter(knob()).dx, closeTo(box.left + 28, 0.5));
    });

    testWidgets('shimmers, except under reduced motion', (tester) async {
      await setUpGlass(tester);
      await pumpSlide(tester, onConfirmed: () {});
      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pumpWidget(
        scene(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SizedBox(width: 300, child: GlassSlideToConfirm(onConfirmed: () {})),
          ),
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
      // And with reduced motion, a confirm lands at once.
      await tester.dragFrom(knobStart(tester), const Offset(240, 0));
      await tester.pump();
      final box = tester.getRect(find.byType(GlassSlideToConfirm));
      expect(tester.getCenter(knob()).dx, closeTo(box.right - 28, 0.5));
    });
  });

  group('GlassAvatar', () {
    testWidgets('shows initials, a status dot and labels itself', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        scene(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassAvatar(key: Key('a'), initials: 'ada lovelace', status: GlassAvatarStatus.online),
              GlassAvatar(key: Key('b'), initials: 'bob'),
              GlassAvatar(key: Key('c'), semanticLabel: 'Guest'),
            ],
          ),
        ),
      );
      expect(find.text('AL'), findsOneWidget);
      expect(find.text('BO'), findsOneWidget);
      final a = tester.getSemantics(find.byKey(const Key('a')));
      expect(a.label, 'AL');
      expect(a.value, 'Online');
      expect(tester.getSemantics(find.byKey(const Key('c'))).label, 'Guest');
      // The dot is the theme's green, and the avatar is cut round it.
      final dots = find.descendant(
        of: find.byKey(const Key('a')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == GlassThemeData.light().on,
        ),
      );
      expect(dots, findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('a')), matching: find.byType(ClipPath)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('b')), matching: find.byType(ClipPath)), findsNothing);
      expect(tester.getSize(find.byKey(const Key('a'))), const Size(40, 40));
      handle.dispose();
    });

    testWidgets('away and busy dots, and an image', (tester) async {
      await setUpGlass(tester);
      await tester.pumpWidget(
        scene(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlassAvatar(key: Key('away'), initials: 'A', status: GlassAvatarStatus.away, size: 56),
              const GlassAvatar(key: Key('busy'), initials: 'B', status: GlassAvatarStatus.busy),
              GlassAvatar(key: const Key('img'), initials: 'IM', image: MemoryImage(Uint8List(0))),
            ],
          ),
        ),
      );
      Color? dot(String key) {
        final box = tester.widgetList<DecoratedBox>(
          find.descendant(of: find.byKey(Key(key)), matching: find.byType(DecoratedBox)),
        );
        return box.map((b) => (b.decoration as BoxDecoration).color).firstOrNull;
      }

      expect(dot('away'), const Color(0xFFFF9F0A));
      expect(dot('busy'), GlassThemeData.light().destructive);
      expect(tester.getSize(find.byKey(const Key('away'))), const Size(56, 56));
      expect(find.descendant(of: find.byKey(const Key('img')), matching: find.byType(Image)), findsOneWidget);
      // Until the picture shows, the initials do.
      expect(find.text('IM'), findsOneWidget);
      await tester.pump();
    });

    testWidgets('a group overlaps and counts the rest', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      final people = [
        for (final n in ['AB', 'CD', 'EF', 'GH', 'IJ', 'KL']) GlassAvatar(initials: n),
      ];
      await tester.pumpWidget(scene(GlassAvatarGroup(max: 3, children: people)));
      expect(find.text('AB'), findsOneWidget);
      expect(find.text('EF'), findsOneWidget);
      expect(find.text('GH'), findsNothing);
      expect(find.text('+3'), findsOneWidget);
      expect(find.semantics.byLabel('3 more'), findsOne);
      // Four circles of 40, each 28 after the last.
      expect(tester.getSize(find.byType(GlassAvatarGroup)), const Size(28 * 3 + 40, 40));
      expect(tester.getTopLeft(find.text('CD')).dx, greaterThan(tester.getTopLeft(find.text('AB')).dx));

      await tester.pumpWidget(scene(GlassAvatarGroup(max: null, children: people)));
      expect(find.textContaining('+'), findsNothing);
      expect(find.text('KL'), findsOneWidget);
      await tester.pumpWidget(scene(GlassAvatarGroup(max: 6, children: people)));
      expect(find.textContaining('+'), findsNothing);

      // Right to left, the first is at the right.
      await tester.pumpWidget(scene(_rtl(GlassAvatarGroup(max: 2, children: people))));
      expect(tester.getTopLeft(find.text('CD')).dx, lessThan(tester.getTopLeft(find.text('AB')).dx));
      expect(find.text('+4'), findsOneWidget);
      handle.dispose();
    });
  });

  group('GlassColorSwatches', () {
    const colors = [Color(0xFFFF3B30), Color(0xFF34C759), Color(0xFF007AFF)];
    const names = ['Red', 'Green', 'Blue'];

    Widget swatches(Color? value, ValueChanged<Color>? onChanged, {FocusNode? focus, List<String>? labels = names}) =>
        GlassColorSwatches(
          colors: colors,
          value: value,
          labels: labels,
          onChanged: onChanged,
          focusNode: focus,
          semanticLabel: 'Colour',
        );

    testWidgets('taps select, and the picked one springs larger', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      Color? value = colors[0];
      await tester.pumpWidget(
        scene(StatefulBuilder(builder: (context, setState) => swatches(value, (c) => setState(() => value = c)))),
      );
      await tester.tap(find.bySemanticsLabel('Green'));
      await settle(tester);
      expect(value, colors[1]);
      expect(find.semantics.byLabel('Green').evaluate().single.flagsCollection.isChecked, isTrue);
      expect(find.semantics.byLabel('Red').evaluate().single.flagsCollection.isChecked, isFalse);
      expect(find.semantics.byLabel('Colour'), findsOne);
      final scales =
          tester
              .widgetList<Transform>(
                find.descendant(of: find.byType(GlassColorSwatches), matching: find.byType(Transform)),
              )
              .map((t) => t.transform.getMaxScaleOnAxis())
              .toList();
      expect(scales[1], closeTo(1.08, 0.001));
      expect(scales[0], closeTo(1, 0.001));
      handle.dispose();
    });

    testWidgets('arrows move the pick round, mirrored right to left', (tester) async {
      await setUpGlass(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      Color? value;
      Widget build(bool rtl) {
        final child = StatefulBuilder(
          builder: (context, setState) => swatches(value, (c) => setState(() => value = c), focus: focus),
        );
        return scene(rtl ? _rtl(child) : child);
      }

      await tester.pumpWidget(build(false));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, colors[0]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, colors[1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, colors[0], reason: 'wraps round');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, colors[2], reason: 'wraps back');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(value, colors[0]);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value, colors[2]);

      await tester.pumpWidget(build(true));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, colors[1]);
      await settle(tester);
    });

    testWidgets('labels default to hex; disabled ignores taps', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      var calls = 0;
      await tester.pumpWidget(scene(swatches(null, (_) => calls++, labels: null)));
      expect(find.semantics.byLabel('#FF3B30'), findsOne);
      expect(find.semantics.byLabel('#007AFF'), findsOne);
      await tester.tap(find.bySemanticsLabel('#007AFF'));
      expect(calls, 1);

      await tester.pumpWidget(scene(swatches(null, null, labels: null)));
      await tester.tap(find.bySemanticsLabel('#007AFF'), warnIfMissed: false);
      expect(calls, 1);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(GlassColorSwatches), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.35);
      handle.dispose();
    });
  });

  group('GlassKnob', () {
    Future<double Function()> pumpKnob(
      WidgetTester tester, {
      double value = 0,
      double min = 0,
      double max = 1,
      int? divisions,
      FocusNode? focus,
      bool enabled = true,
    }) async {
      var current = value;
      await tester.pumpWidget(
        scene(
          StatefulBuilder(
            builder:
                (context, setState) => GlassKnob(
                  value: current,
                  min: min,
                  max: max,
                  divisions: divisions,
                  focusNode: focus,
                  semanticLabel: 'Volume',
                  onChanged: enabled ? (v) => setState(() => current = v) : null,
                ),
          ),
        ),
      );
      return () => current;
    }

    testWidgets('a vertical drag from the middle turns it, clamped', (tester) async {
      await setUpGlass(tester);
      final value = await pumpKnob(tester);
      final center = tester.getCenter(find.byType(GlassKnob));
      await tester.dragFrom(center, const Offset(0, -100));
      await settle(tester);
      expect(value(), closeTo(0.5, 0.01));
      await tester.dragFrom(center, const Offset(0, -1000));
      await settle(tester);
      expect(value(), 1);
      await tester.dragFrom(center, const Offset(0, 1000));
      await settle(tester);
      expect(value(), 0);
      // Right turns it up too.
      await tester.dragFrom(center, const Offset(50, 0));
      await settle(tester);
      expect(value(), closeTo(0.25, 0.01));
    });

    testWidgets('a drag round the rim turns with the finger', (tester) async {
      await setUpGlass(tester);
      final value = await pumpKnob(tester, value: 0.5);
      final center = tester.getCenter(find.byType(GlassKnob));
      // From the top of the rim, a quarter turn clockwise.
      final gesture = await tester.startGesture(center + const Offset(0, -28));
      for (var i = 1; i <= 9; i++) {
        final a = -1.5707963 + i * 1.5707963 / 9;
        await gesture.moveTo(center + Offset(28 * math.cos(a), 28 * math.sin(a)));
        await tester.pump();
      }
      await gesture.up();
      await settle(tester);
      expect(value(), closeTo(0.5 + 1 / 3, 0.02));
    });

    testWidgets('divisions snap the value', (tester) async {
      await setUpGlass(tester);
      final value = await pumpKnob(tester, divisions: 10);
      await tester.dragFrom(tester.getCenter(find.byType(GlassKnob)), const Offset(0, -33));
      await settle(tester);
      expect(value(), closeTo(0.2, 1e-9));
    });

    testWidgets('the scroll wheel turns it a step a notch', (tester) async {
      await setUpGlass(tester);
      final value = await pumpKnob(tester, value: 0.5);
      final center = tester.getCenter(find.byType(GlassKnob));
      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, -20)));
      await tester.pump();
      expect(value(), closeTo(0.55, 1e-9));
      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, 40)));
      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, 40)));
      await tester.pump();
      expect(value(), closeTo(0.45, 1e-9));
      await settle(tester);
    });

    testWidgets('keys step it within its range', (tester) async {
      await setUpGlass(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final value = await pumpKnob(tester, value: 15, min: 10, max: 20, divisions: 10, focus: focus);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value(), 16);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(value(), 14);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(value(), 19);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(value(), 20, reason: 'clamped at max');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(value(), 10);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(value(), 10, reason: 'clamped at min');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value(), 20);
      await settle(tester);
    });

    testWidgets('is adjustable to a screen reader', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      final value = await pumpKnob(tester, value: 0.5);
      final node = tester.getSemantics(find.byType(GlassKnob));
      expect(node.label, 'Volume');
      expect(node.value, '50%');
      expect(node.increasedValue, '55%');
      expect(node.decreasedValue, '45%');
      expect(node.flagsCollection.isSlider, isTrue);
      tester.semantics.performAction(find.semantics.byLabel('Volume'), SemanticsAction.increase);
      await tester.pump();
      expect(value(), closeTo(0.55, 1e-9));

      await tester.pumpWidget(
        scene(
          GlassKnob(
            value: 3,
            max: 10,
            semanticLabel: 'Gain',
            semanticFormatter: (v) => '${v.round()} dB',
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.getSemantics(find.byType(GlassKnob)).value, '3 dB');
      await settle(tester);
      handle.dispose();
    });

    testWidgets('disabled ignores drags, wheels and keys', (tester) async {
      await setUpGlass(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final value = await pumpKnob(tester, value: 0.5, focus: focus, enabled: false);
      final center = tester.getCenter(find.byType(GlassKnob));
      await tester.dragFrom(center, const Offset(0, -100));
      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, -20)));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(value(), 0.5);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(GlassKnob), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.35);
    });

    testWidgets('in a list, it turns rather than the list scrolling', (tester) async {
      await setUpGlass(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var value = 0.0;
      await tester.pumpWidget(
        scene(
          SizedBox(
            height: 200,
            child: StatefulBuilder(
              builder:
                  (context, setState) => ListView(
                    controller: controller,
                    children: [
                      const SizedBox(height: 40),
                      Center(child: GlassKnob(value: value, onChanged: (v) => setState(() => value = v))),
                      const SizedBox(height: 600),
                    ],
                  ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(GlassKnob));
      await tester.dragFrom(center, const Offset(0, -60));
      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, -20)));
      await settle(tester);
      expect(value, closeTo(0.35, 0.01));
      expect(controller.offset, 0);
    });
  });

  testWidgets('every extra control is labelled', (tester) async {
    await setUpGlass(tester, size: const Size(800, 900), ratio: 1);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      scene(
        SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: 300, child: GlassSlideToConfirm(onConfirmed: () {})),
              const GlassAvatar(initials: 'AB', status: GlassAvatarStatus.online),
              const GlassAvatarGroup(max: 1, children: [GlassAvatar(initials: 'A'), GlassAvatar(initials: 'B')]),
              GlassColorSwatches(colors: const [Color(0xFFFF0000), Color(0xFF00FF00)], value: null, onChanged: (_) {}),
              GlassKnob(value: 0.5, semanticLabel: 'Pan', onChanged: (_) {}),
              GlassCalendar(selectedDate: null, currentDate: DateTime(2027, 3, 10), onDateSelected: (_) {}),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  group('GlassCalendar', () {
    final today = DateTime(2027, 3, 10);
    Finder day(int y, int m, int d) => find.byKey(ValueKey<DateTime>(DateTime(y, m, d)));

    testWidgets('a date picked elsewhere brings its month into view', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      DateTime? selected = DateTime(2027, 3, 3);
      late StateSetter update;
      await tester.pumpWidget(
        scene(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return GlassCalendar(selectedDate: selected, currentDate: today, onDateSelected: (_) {});
            },
          ),
        ),
      );
      expect(find.text('March 2027'), findsOneWidget);
      update(() => selected = DateTime(2028, 7, 4, 13, 30));
      await settle(tester);
      expect(find.text('July 2028'), findsOneWidget);
      expect(tester.getSemantics(day(2028, 7, 4)).flagsCollection.isSelected, isTrue);
      update(() => selected = null);
      await settle(tester);
      expect(find.text('July 2028'), findsOneWidget);
    });

    Future<List<DateTime>> pumpCalendar(
      WidgetTester tester, {
      DateTime? selected,
      DateTime? month,
      DateTime? first,
      DateTime? last,
      int firstDayOfWeek = DateTime.monday,
      FocusNode? focus,
      bool rtl = false,
    }) async {
      final picked = <DateTime>[];
      var current = selected;
      Widget child = StatefulBuilder(
        builder:
            (context, setState) => GlassCalendar(
              selectedDate: current,
              initialMonth: month,
              currentDate: today,
              firstDate: first,
              lastDate: last,
              firstDayOfWeek: firstDayOfWeek,
              focusNode: focus,
              onDateSelected:
                  (d) => setState(() {
                    current = d;
                    picked.add(d);
                  }),
            ),
      );
      if (rtl) child = _rtl(child);
      await tester.pumpWidget(scene(child));
      return picked;
    }

    testWidgets('tapping a day selects it, and it springs in', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      final handle = tester.ensureSemantics();
      final picked = await pumpCalendar(tester);
      expect(find.text('March 2027'), findsOneWidget);
      expect(find.semantics.byLabel('Today, Wednesday, 10 March 2027'), findsOne);
      await tester.tap(day(2027, 3, 15));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await settle(tester);
      expect(picked, [DateTime(2027, 3, 15)]);
      final node = tester.getSemantics(day(2027, 3, 15));
      expect(node.label, 'Monday, 15 March 2027');
      expect(node.flagsCollection.isSelected, isTrue);
      handle.dispose();
    });

    testWidgets('a day outside the month selects it and shows its month', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      final picked = await pumpCalendar(tester);
      // March 2027 starts on a Monday, so the last row runs into April.
      await tester.tap(day(2027, 4, 1));
      await settle(tester);
      expect(picked, [DateTime(2027, 4, 1)]);
      expect(find.text('April 2027'), findsOneWidget);
    });

    testWidgets('the chevrons change month, across the year', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester, month: DateTime(2027, 12));
      expect(find.text('December 2027'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await settle(tester);
      expect(find.text('January 2028'), findsOneWidget);
      // 1 January 2028 is a Saturday: five days of December lead in.
      expect(day(2027, 12, 27), findsOneWidget);
      expect(day(2027, 12, 26), findsNothing);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await settle(tester);
      expect(find.text('November 2027'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('days out of bounds cannot be picked, nor months beyond', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      final handle = tester.ensureSemantics();
      final picked = await pumpCalendar(tester, first: DateTime(2027, 3, 5), last: DateTime(2027, 3, 25, 18));
      await tester.tap(day(2027, 3, 4));
      await tester.tap(day(2027, 3, 26));
      await settle(tester);
      expect(picked, isEmpty);
      expect(tester.getSemantics(day(2027, 3, 4)).flagsCollection.isEnabled, isFalse);
      await tester.tap(day(2027, 3, 5));
      await tester.tap(day(2027, 3, 25));
      await settle(tester);
      expect(picked, [DateTime(2027, 3, 5), DateTime(2027, 3, 25)]);
      await tester.tap(find.bySemanticsLabel('Next month'), warnIfMissed: false);
      await tester.tap(find.bySemanticsLabel('Previous month'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('March 2027'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('firstDayOfWeek lays the weeks out', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      await pumpCalendar(tester);
      // Monday first: 1 March 2027 is a Monday, so it starts the grid.
      expect(day(2027, 2, 28), findsNothing);
      final monday = tester.getTopLeft(day(2027, 3, 1));
      final initials = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(initials.sublist(1, 8), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);

      await pumpCalendar(tester, firstDayOfWeek: DateTime.sunday);
      expect(day(2027, 2, 28), findsOneWidget);
      final sunday = tester.getTopLeft(day(2027, 2, 28));
      expect(sunday, monday);
      expect(tester.getTopLeft(day(2027, 3, 1)).dx, greaterThan(sunday.dx));
      final sundayFirst = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(sundayFirst.sublist(1, 8), ['S', 'M', 'T', 'W', 'T', 'F', 'S']);
    });

    testWidgets('swiping changes month, mirrored right to left', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      await pumpCalendar(tester);
      await tester.fling(day(2027, 3, 17), const Offset(-150, 0), 1000);
      await settle(tester);
      expect(find.text('April 2027'), findsOneWidget);
      await tester.fling(day(2027, 4, 14), const Offset(150, 0), 1000);
      await settle(tester);
      await tester.fling(day(2027, 3, 17), const Offset(150, 0), 1000);
      await settle(tester);
      expect(find.text('February 2027'), findsOneWidget);
      // A short slow drag isn't a swipe.
      await tester.timedDrag(day(2027, 2, 17), const Offset(-20, 0), const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('February 2027'), findsOneWidget);

      await pumpCalendar(tester, rtl: true, month: DateTime(2027, 3));
      await tester.fling(day(2027, 3, 17), const Offset(-150, 0), 1000);
      await settle(tester);
      expect(find.text('February 2027'), findsOneWidget);
    });

    testWidgets('arrows move a focused day and enter picks it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final picked = await pumpCalendar(tester, selected: DateTime(2027, 3, 15), focus: focus);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(picked, [DateTime(2027, 3, 23)]);
      // Past the month's end it moves into the next.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(find.text('April 2027'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(picked.last, DateTime(2027, 4, 6));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(picked.last, DateTime(2027, 3, 1));
    });

    testWidgets('right to left, arrows are mirrored and bounds hold', (tester) async {
      await setUpGlass(tester, size: const Size(400, 460));
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final picked = await pumpCalendar(
        tester,
        selected: DateTime(2027, 3, 15),
        focus: focus,
        rtl: true,
        last: DateTime(2027, 3, 16),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(picked, [DateTime(2027, 3, 16)]);
      // In RTL, the first day of the week sits at the right.
      expect(tester.getTopLeft(day(2027, 3, 1)).dx, greaterThan(tester.getTopLeft(day(2027, 3, 2)).dx));
    });
  });

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    testWidgets('extras look right $name', (tester) async {
      await setUpGlass(tester, size: const Size(420, 330));
      await tester.pumpWidget(
        scene(
          dark: dark,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 340, child: GlassSlideToConfirm(onConfirmed: () {}, shimmer: false)),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 340,
                  child: GlassSlideToConfirm(onConfirmed: null, label: 'Disabled', shimmer: false),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const GlassAvatar(initials: 'Ada Lovelace', status: GlassAvatarStatus.online, size: 48),
                    const GlassAvatar(status: GlassAvatarStatus.busy, size: 48),
                    GlassAvatarGroup(
                      max: 3,
                      size: 36,
                      children: [
                        for (final n in ['AB', 'CD', 'EF', 'GH', 'IJ']) GlassAvatar(initials: n, size: 36),
                      ],
                    ),
                    GlassKnob(value: 0.62, onChanged: (_) {}),
                    const GlassKnob(value: 0.3, onChanged: null, size: 48),
                  ],
                ),
                const SizedBox(height: 18),
                GlassColorSwatches(
                  colors: const [
                    Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759), //
                    Color(0xFF007AFF), Color(0xFFAF52DE), Color(0xFFFFFFFF), Color(0xFF1C1C1E),
                  ],
                  value: const Color(0xFF007AFF),
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/extras_$name.png'));
    });

    testWidgets('calendar looks right $name', (tester) async {
      await setUpGlass(tester, size: const Size(380, 440));
      await tester.pumpWidget(
        scene(
          dark: dark,
          GlassCalendar(
            currentDate: DateTime(2027, 3, 10),
            selectedDate: DateTime(2027, 3, 18),
            firstDate: DateTime(2027, 3, 4),
            onDateSelected: (_) {},
          ),
        ),
      );
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/calendar_$name.png'));
    });

    testWidgets('slide to confirm mid-slide and confirmed $name', (tester) async {
      await setUpGlass(tester, size: const Size(380, 200));
      await tester.pumpWidget(
        scene(
          dark: dark,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 340,
                child: GlassSlideToConfirm(key: const Key('mid'), onConfirmed: () {}, shimmer: false),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 340,
                child: GlassSlideToConfirm(
                  key: const Key('done'),
                  onConfirmed: () {},
                  confirmedLabel: 'Confirmed',
                  shimmer: false,
                ),
              ),
            ],
          ),
        ),
      );
      Offset knobOf(String key) =>
          tester.getCenter(find.descendant(of: find.byKey(Key(key)), matching: find.byType(GlassPressable)));
      await tester.dragFrom(knobOf('done'), const Offset(300, 0));
      await settle(tester);
      final gesture = await tester.startGesture(knobOf('mid'));
      await gesture.moveBy(const Offset(140, 0));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/slide_to_confirm_$name.png'));
      await gesture.up();
      await settle(tester);
    });
  }
}

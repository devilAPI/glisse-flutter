import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';
import 'package:glisse/src/rendering/content_lens.dart' show debugImagesRecorded;
import 'package:glisse/src/widgets/thumb_frost.dart';

import 'helpers.dart';

/// A range slider 236px wide: 200px of travel from 18px in.
Widget _range(
  GlassRange Function() get,
  void Function(GlassRange) set, {
  int? divisions,
  bool enabled = true,
  TextDirection direction = TextDirection.ltr,
  FocusNode? focusNode,
  FocusNode? endFocusNode,
  void Function(GlassRange)? onStart,
  void Function(GlassRange)? onEnd,
}) {
  return Directionality(
    textDirection: direction,
    child: SizedBox(
      width: 236,
      child: StatefulBuilder(
        builder:
            (context, setState) => GlassRangeSlider(
              values: get(),
              divisions: divisions,
              focusNode: focusNode,
              endFocusNode: endFocusNode,
              onChangeStart: onStart,
              onChangeEnd: onEnd,
              semanticLabel: 'Price',
              onChanged: enabled ? (v) => setState(() => set(v)) : null,
            ),
      ),
    ),
  );
}

/// Where progress [p] lies on the 236px range slider.
Offset _at(WidgetTester tester, double p) {
  final box = tester.getRect(find.byType(GlassRangeSlider));
  return Offset(box.left + 18 + 200 * p, box.center.dy);
}

/// Turns a wheel by [rows] rows, beyond the drag slop a scrollable loses.
Future<void> _turn(WidgetTester tester, Finder wheel, int rows) =>
    tester.drag(wheel, Offset(0, -(rows * 32.0 + kDragSlopDefault * rows.sign)));

/// Haptic feedback sent to the platform, recorded.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  group('GlassRangeSlider', () {
    testWidgets('dragging the end knob moves the end', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.2, 0.6);
      var started = 0;
      var ended = 0;
      GlassRange? last;
      await tester.pumpWidget(
        scene(
          _range(
            () => values,
            (v) => values = v,
            onStart: (_) => started++,
            onEnd: (v) {
              ended++;
              last = v;
            },
          ),
        ),
      );
      final gesture = await tester.startGesture(_at(tester, 0.6));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(values.start, 0.2);
      expect(values.end, closeTo(0.8, 0.01));
      await gesture.up();
      await settle(tester);
      expect(started, 1);
      expect(ended, 1);
      expect(last, values);
    });

    testWidgets('the nearer knob takes a tap', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.3, 0.7);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      await tester.tapAt(_at(tester, 0.1));
      await settle(tester);
      expect(values.start, closeTo(0.1, 0.01));
      expect(values.end, 0.7);
      await tester.tapAt(_at(tester, 0.55));
      await settle(tester);
      // 0.55 is nearer the end at 0.7 than the start at 0.1.
      expect(values.start, closeTo(0.1, 0.01));
      expect(values.end, closeTo(0.55, 0.01));
    });

    testWidgets('knobs cannot cross', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.2, 0.5);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      final gesture = await tester.startGesture(_at(tester, 0.2));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(16, 0));
        await tester.pump();
      }
      expect(values.start, 0.5);
      expect(values.end, 0.5);
      await gesture.up();
      await settle(tester);
      expect(values.start <= values.end, isTrue);
    });

    testWidgets('knobs together part the way the drag goes', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.5, 0.5);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      var gesture = await tester.startGesture(_at(tester, 0.5));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.up();
      await settle(tester);
      expect(values.start, 0.5);
      expect(values.end, closeTo(0.7, 0.01));

      values = const GlassRange(0.5, 0.5);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      gesture = await tester.startGesture(_at(tester, 0.5));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.up();
      await settle(tester);
      expect(values.start, closeTo(0.3, 0.01));
      expect(values.end, 0.5);
    });

    testWidgets('knobs together at the max part leftwards', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(1, 1);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      final gesture = await tester.startGesture(_at(tester, 1));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-10, 0));
      await gesture.up();
      await settle(tester);
      expect(values.start, closeTo(0.8, 0.01));
      expect(values.end, 1);
    });

    testWidgets('snaps to divisions', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0, 1);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v, divisions: 4)));
      await tester.tapAt(_at(tester, 0.3));
      await settle(tester);
      expect(values, const GlassRange(0.25, 1));
    });

    testWidgets('mirrors right to left', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.2, 0.6);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v, direction: TextDirection.rtl)));
      // On the left lies the top of the range: the end knob, at 0.6, sits at 40% from the left.
      await tester.tapAt(_at(tester, 0.1));
      await settle(tester);
      expect(values.start, 0.2);
      expect(values.end, closeTo(0.9, 0.01));
    });

    testWidgets('disabled ignores input', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.2, 0.6);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v, enabled: false)));
      await tester.tapAt(_at(tester, 0.0));
      await tester.dragFrom(_at(tester, 0.6), const Offset(60, 0));
      await settle(tester);
      expect(values, const GlassRange(0.2, 0.6));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(GlassRangeSlider), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.35);
    });

    testWidgets('arrow keys move the focused knob, not past the other', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.4, 0.5);
      final start = FocusNode();
      final end = FocusNode();
      addTearDown(start.dispose);
      addTearDown(end.dispose);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v, focusNode: start, endFocusNode: end)));
      start.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(values.start, closeTo(0.35, 1e-9));
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(values.start, closeTo(0.5, 1e-9));
      expect(values.end, closeTo(0.5, 1e-9));

      end.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(values.end, closeTo(0.5, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(values.end, 1);
    });

    testWidgets('right to left, the right arrow lowers', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.4, 0.8);
      final start = FocusNode();
      addTearDown(start.dispose);
      await tester.pumpWidget(
        scene(_range(() => values, (v) => values = v, focusNode: start, direction: TextDirection.rtl)),
      );
      start.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(values.start, closeTo(0.35, 1e-9));
    });

    testWidgets('each knob is an adjustable slider', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      var values = const GlassRange(0.2, 0.6);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      expect(find.bySemanticsLabel('Start'), findsOneWidget);
      final startNode = tester.getSemantics(find.bySemanticsLabel('Start'));
      expect(
        startNode,
        containsSemantics(
          label: 'Start',
          value: '20%',
          increasedValue: '25%',
          decreasedValue: '15%',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('End')),
        containsSemantics(label: 'End', value: '60%', isSlider: true, hasIncreaseAction: true),
      );
      tester.semantics.increase(find.semantics.byLabel('Start'));
      await tester.pump();
      expect(values.start, closeTo(0.25, 1e-9));
      expect(find.bySemanticsLabel('Price'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a met knob cannot be increased past the other', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(scene(_range(() => const GlassRange(0.5, 0.5), (_) {})));
      final start = tester.getSemantics(find.bySemanticsLabel('Start'));
      expect(start, containsSemantics(hasIncreaseAction: false, hasDecreaseAction: true));
      handle.dispose();
    });

    testWidgets('a held knob lifts into a lens, and settles when let go', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.2, 0.6);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      expect(find.byType(ThumbFrost), findsNothing);
      final before = debugImagesRecorded;
      final press = await tester.startGesture(_at(tester, 0.6));
      await settle(tester);
      // Only the held knob lifts, frosting the page under its lens, which
      // shows the track it records.
      final frost = tester.widget<ThumbFrost>(find.byType(ThumbFrost));
      expect(frost.lift, closeTo(1, 0.01));
      expect(
        frost.rect.center.dx,
        closeTo(_at(tester, 0.6).dx - tester.getTopLeft(find.byType(GlassRangeSlider)).dx, 1),
      );
      expect(frost.rect.size, const Size(60, 40));
      expect(debugImagesRecorded - before, inInclusiveRange(1, 2));
      await press.up();
      await settle(tester);
      expect(find.byType(ThumbFrost), findsNothing);
      expect(values, const GlassRange(0.2, 0.6));
    });

    testWidgets('reduced motion lifts a knob at once', (tester) async {
      await setUpGlass(tester);
      var values = const GlassRange(0.2, 0.6);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: scene(_range(() => values, (v) => values = v)),
        ),
      );
      final press = await tester.startGesture(_at(tester, 0.2));
      await tester.pump();
      expect(tester.widget<ThumbFrost>(find.byType(ThumbFrost)).lift, 1);
      await press.up();
      await tester.pump();
      expect(find.byType(ThumbFrost), findsNothing);
    });

    // On the web each recording reads the GPU back synchronously, so a knob
    // dragged slowly must not record its lens's content every frame.
    testWidgets('dragging a knob slowly records nothing new', (tester) async {
      await setUpGlass(tester, size: const Size(500, 300));
      var values = const GlassRange(0.2, 0.6);
      await tester.pumpWidget(scene(_range(() => values, (v) => values = v)));
      for (final (knob, from, step) in [('end', 0.6, 0.5), ('start', 0.2, -0.5)]) {
        final drag = await tester.startGesture(_at(tester, from), kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 100));
        // Lifting may record, once the lens is up.
        await drag.moveBy(Offset(step * 24, 0));
        await settle(tester);
        final before = debugImagesRecorded;
        for (var i = 0; i < 60; i++) {
          await drag.moveBy(Offset(step, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(debugImagesRecorded - before, lessThanOrEqualTo(2), reason: 'recorded while dragging the $knob knob');
        await drag.up();
        await settle(tester);
      }
      expect(values.start, closeTo(0.2 - 42 / 200, 0.01));
      expect(values.end, closeTo(0.6 + 42 / 200, 0.01));
    });

    for (final dark in [false, true]) {
      testWidgets('looks right held ${dark ? 'dark' : 'light'}', (tester) async {
        await setUpGlass(tester, size: const Size(300, 220), ratio: 3);
        var held = const GlassRange(0.2, 0.45);
        var met = const GlassRange(0.5, 0.5);
        await tester.pumpWidget(
          scene(
            dark: dark,
            SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassRangeSlider(values: const GlassRange(0, 0.6), onChanged: (_) {}),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder:
                        (context, setState) => GlassRangeSlider(
                          key: const Key('held'),
                          values: held,
                          onChanged: (v) => setState(() => held = v),
                        ),
                  ),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder:
                        (context, setState) => GlassRangeSlider(
                          key: const Key('met'),
                          values: met,
                          onChanged: (v) => setState(() => met = v),
                        ),
                  ),
                  const SizedBox(height: 8),
                  const GlassRangeSlider(values: GlassRange(0.3, 0.8), onChanged: null),
                ],
              ),
            ),
          ),
        );
        await settle(tester);
        final box = tester.getRect(find.byKey(const Key('held')));
        final gesture = await tester.startGesture(Offset(box.left + 18 + (box.width - 36) * 0.45, box.center.dy));
        await gesture.moveBy(const Offset(20, 0));
        await gesture.moveBy(const Offset(10, 0));
        // Knobs that met, parted a little: the lifted one's lens over the other.
        final together = await tester.startGesture(tester.getCenter(find.byKey(const Key('met'))));
        await together.moveBy(const Offset(20, 0));
        await together.moveBy(const Offset(-8, 0));
        await settle(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/range_slider_${dark ? 'dark' : 'light'}.png'),
        );
        await gesture.up();
        await together.up();
        await settle(tester);
      });
    }
  });

  group('GlassPicker', () {
    const fruits = ['Apple', 'Banana', 'Cherry', 'Grape', 'Lemon', 'Mango'];

    Widget picker({
      required ValueChanged<int>? onChanged,
      bool looping = false,
      int initial = 0,
      FocusNode? focusNode,
    }) => SizedBox(
      width: 200,
      child: GlassPicker(
        items: fruits,
        initialItem: initial,
        looping: looping,
        focusNode: focusNode,
        semanticLabel: 'Fruit',
        onSelectedItemChanged: onChanged,
      ),
    );

    testWidgets('scrolling selects a row, with a click each', (tester) async {
      await setUpGlass(tester);
      final haptics = _recordHaptics(tester);
      int? selected;
      await tester.pumpWidget(scene(picker(onChanged: (i) => selected = i)));
      await _turn(tester, find.byType(GlassPicker), 2);
      await settle(tester);
      expect(selected, 2);
      expect(haptics, isNotEmpty);
      expect(haptics.every((h) => h == 'HapticFeedbackType.selectionClick'), isTrue);
    });

    testWidgets('tapping a row turns to it', (tester) async {
      await setUpGlass(tester);
      _recordHaptics(tester);
      int? selected;
      await tester.pumpWidget(scene(picker(onChanged: (i) => selected = i)));
      await tester.tap(find.text('Banana'));
      await settle(tester);
      expect(selected, 1);
    });

    testWidgets('a looping picker goes round', (tester) async {
      await setUpGlass(tester);
      _recordHaptics(tester);
      int? selected;
      await tester.pumpWidget(scene(picker(looping: true, onChanged: (i) => selected = i)));
      await _turn(tester, find.byType(GlassPicker), -1);
      await settle(tester);
      expect(selected, fruits.length - 1);
    });

    testWidgets('a picker that does not loop stops at its ends', (tester) async {
      await setUpGlass(tester);
      _recordHaptics(tester);
      int? selected;
      await tester.pumpWidget(scene(picker(onChanged: (i) => selected = i)));
      await _turn(tester, find.byType(GlassPicker), -2);
      await settle(tester);
      expect(selected, isNull);
      await _turn(tester, find.byType(GlassPicker), 20);
      await settle(tester);
      expect(selected, fruits.length - 1);
    });

    testWidgets('arrow keys turn the wheel', (tester) async {
      await setUpGlass(tester);
      _recordHaptics(tester);
      int? selected;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(scene(picker(focusNode: focus, onChanged: (i) => selected = i)));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(selected, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(selected, 1);
    });

    testWidgets('describes the chosen row and adjusts', (tester) async {
      await setUpGlass(tester);
      _recordHaptics(tester);
      final handle = tester.ensureSemantics();
      int? selected;
      await tester.pumpWidget(scene(picker(initial: 2, onChanged: (i) => selected = i)));
      final node = tester.getSemantics(find.bySemanticsLabel('Fruit'));
      expect(
        node,
        containsSemantics(
          label: 'Fruit',
          value: 'Cherry',
          increasedValue: 'Grape',
          decreasedValue: 'Banana',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Fruit'));
      await settle(tester);
      expect(selected, 3);
      expect(tester.getSemantics(find.bySemanticsLabel('Fruit')), containsSemantics(value: 'Grape'));
      handle.dispose();
    });

    testWidgets('disabled does not scroll', (tester) async {
      await setUpGlass(tester);
      await tester.pumpWidget(scene(picker(onChanged: null)));
      await _turn(tester, find.byType(GlassPicker), 2);
      await settle(tester);
      final wheel = tester.widget<ListWheelScrollView>(find.byType(ListWheelScrollView));
      expect(wheel.controller!.offset, 0);
    });

    testWidgets('an empty picker builds, looping or not', (tester) async {
      await setUpGlass(tester);
      for (final looping in [false, true]) {
        await tester.pumpWidget(
          scene(
            SizedBox(width: 200, child: GlassPicker(items: const [], looping: looping, onSelectedItemChanged: (_) {})),
          ),
        );
        await _turn(tester, find.byType(GlassPicker), 1);
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('takes widgets as rows', (tester) async {
      await setUpGlass(tester);
      _recordHaptics(tester);
      int? selected;
      await tester.pumpWidget(
        scene(
          SizedBox(
            width: 200,
            child: GlassPicker(
              onSelectedItemChanged: (i) => selected = i,
              children: const [Text('One'), Text('Two'), Text('Three')],
            ),
          ),
        ),
      );
      expect(find.text('Two'), findsOneWidget);
      await _turn(tester, find.byType(GlassPicker), 1);
      await settle(tester);
      expect(selected, 1);
    });
  });

  group('GlassDatePicker', () {
    Finder wheel(int i) => find.byType(ListWheelScrollView).at(i);

    testWidgets('the day keeps within February', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      _recordHaptics(tester);
      final dates = <DateTime>[];
      await tester.pumpWidget(scene(GlassDatePicker(initialDate: DateTime(2023, 1, 30), onDateTimeChanged: dates.add)));
      // January to February.
      await _turn(tester, wheel(0), 1);
      await settle(tester);
      expect(dates.last, DateTime(2023, 2, 28));
      // The day wheel has rolled back from 30 to 28.
      final days = tester.widget<ListWheelScrollView>(wheel(1)).controller! as FixedExtentScrollController;
      expect(days.selectedItem % 31, 27);
      // 2024 has a 29th of February.
      await _turn(tester, wheel(1), 1);
      await settle(tester);
      expect(dates.last, DateTime(2023, 2, 28));
      await _turn(tester, wheel(2), 1);
      await settle(tester);
      expect(dates.last.year, 2024);
      expect(dates.last.month, 2);
      expect(dates.last.day, 28);
    });

    testWidgets('a leap February has 29 days', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      _recordHaptics(tester);
      final dates = <DateTime>[];
      await tester.pumpWidget(
        scene(GlassDatePicker(initialDate: DateTime(2024, 3, 30, 8, 15), onDateTimeChanged: dates.add)),
      );
      // March back to February.
      await _turn(tester, wheel(0), -1);
      await settle(tester);
      expect(dates.last, DateTime(2024, 2, 29, 8, 15));
      // Then to 2025, which has none.
      await _turn(tester, wheel(2), 1);
      await settle(tester);
      expect(dates.last, DateTime(2025, 2, 28, 8, 15));
    });

    testWidgets('years keep within their bounds', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      _recordHaptics(tester);
      final dates = <DateTime>[];
      await tester.pumpWidget(
        scene(
          GlassDatePicker(
            initialDate: DateTime(2030, 5, 5),
            minimumYear: 2000,
            maximumYear: 2025,
            onDateTimeChanged: dates.add,
          ),
        ),
      );
      expect(find.text('2025'), findsOneWidget);
      await _turn(tester, wheel(2), 5);
      await settle(tester);
      expect(dates, isEmpty);
    });

    testWidgets('each wheel is described', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        scene(GlassDatePicker(initialDate: DateTime(2024, 7, 4), semanticLabel: 'Birthday', onDateTimeChanged: (_) {})),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Month')), containsSemantics(value: 'July'));
      expect(tester.getSemantics(find.bySemanticsLabel('Day')), containsSemantics(value: '4'));
      expect(tester.getSemantics(find.bySemanticsLabel('Year')), containsSemantics(value: '2024'));
      expect(find.bySemanticsLabel('Birthday'), findsOneWidget);
      handle.dispose();
    });
  });

  group('GlassTimePicker', () {
    Finder wheel(int i) => find.byType(ListWheelScrollView).at(i);

    testWidgets('12-hour: passing 12 turns AM to PM', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      _recordHaptics(tester);
      final times = <DateTime>[];
      await tester.pumpWidget(
        scene(GlassTimePicker(initialTime: DateTime(2026, 3, 1, 11, 30), onDateTimeChanged: times.add)),
      );
      await _turn(tester, wheel(0), 1);
      await settle(tester);
      expect(times.last, DateTime(2026, 3, 1, 12, 30));
      final periods = tester.widget<ListWheelScrollView>(wheel(2)).controller! as FixedExtentScrollController;
      expect(periods.selectedItem, 1);
      // And back.
      await _turn(tester, wheel(0), -1);
      await settle(tester);
      expect(times.last, DateTime(2026, 3, 1, 11, 30));
      expect(periods.selectedItem, 0);
      // The AM/PM wheel on its own.
      await _turn(tester, wheel(2), 1);
      await settle(tester);
      expect(times.last, DateTime(2026, 3, 1, 23, 30));
    });

    testWidgets('24-hour shows no AM/PM, and minutes step', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      _recordHaptics(tester);
      final times = <DateTime>[];
      await tester.pumpWidget(
        scene(
          GlassTimePicker(
            initialTime: DateTime(2026, 3, 1, 21, 7),
            use24hFormat: true,
            minuteInterval: 5,
            onDateTimeChanged: times.add,
          ),
        ),
      );
      expect(find.byType(ListWheelScrollView), findsNWidgets(2));
      expect(find.text('AM'), findsNothing);
      await _turn(tester, wheel(1), 2);
      await settle(tester);
      expect(times.last, DateTime(2026, 3, 1, 21, 15));
      await _turn(tester, wheel(0), 3);
      await settle(tester);
      expect(times.last, DateTime(2026, 3, 1, 0, 15));
    });
  });

  group('GlassRating', () {
    Widget rating(
      double Function() get,
      void Function(double) set, {
      bool allowHalf = false,
      bool enabled = true,
      TextDirection direction = TextDirection.ltr,
      FocusNode? focusNode,
    }) {
      return Directionality(
        textDirection: direction,
        child: StatefulBuilder(
          builder:
              (context, setState) => GlassRating(
                value: get(),
                allowHalf: allowHalf,
                focusNode: focusNode,
                semanticLabel: 'Rating',
                onChanged: enabled ? (v) => setState(() => set(v)) : null,
              ),
        ),
      );
    }

    // Stars are 28px with 4px gaps.
    Offset star(WidgetTester tester, int index, [double within = 0.75]) {
      final box = tester.getRect(find.byType(GlassRating));
      return Offset(box.left + index * 32 + 28 * within, box.center.dy);
    }

    testWidgets('tapping a star rates', (tester) async {
      await setUpGlass(tester);
      var value = 0.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v)));
      expect(tester.getSize(find.byType(GlassRating)), const Size(5 * 28 + 4 * 4, 28));
      await tester.tapAt(star(tester, 2));
      await settle(tester);
      expect(value, 3);
      await tester.tapAt(star(tester, 0, 0.2));
      await settle(tester);
      expect(value, 1);
    });

    testWidgets('half stars', (tester) async {
      await setUpGlass(tester);
      var value = 0.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v, allowHalf: true)));
      await tester.tapAt(star(tester, 3, 0.25));
      await settle(tester);
      expect(value, 3.5);
      await tester.tapAt(star(tester, 3, 0.75));
      await settle(tester);
      expect(value, 4);
    });

    testWidgets('dragging across sets the rating', (tester) async {
      await setUpGlass(tester);
      var value = 1.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v)));
      final gesture = await tester.startGesture(star(tester, 0));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(value, 4);
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      expect(value, 0);
      await gesture.up();
      await settle(tester);
    });

    testWidgets('the touched star pops and settles', (tester) async {
      await setUpGlass(tester);
      var value = 0.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v)));
      await tester.tapAt(star(tester, 1));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await settle(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('mirrors right to left', (tester) async {
      await setUpGlass(tester);
      var value = 0.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v, direction: TextDirection.rtl)));
      // The leftmost star is the fifth.
      await tester.tapAt(star(tester, 0, 0.5));
      await settle(tester);
      expect(value, 5);
    });

    testWidgets('read-only ignores taps and offers no actions', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      var value = 2.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v, enabled: false)));
      await tester.tapAt(star(tester, 4));
      await settle(tester);
      expect(value, 2);
      expect(
        tester.getSemantics(find.byType(GlassRating)),
        containsSemantics(value: '2 of 5 stars', hasIncreaseAction: false, hasDecreaseAction: false),
      );
      handle.dispose();
    });

    testWidgets('arrow keys step by a star, or half', (tester) async {
      await setUpGlass(tester);
      var value = 2.0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v, focusNode: focus)));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 5);

      await tester.pumpWidget(scene(rating(() => value, (v) => value = v, focusNode: focus, allowHalf: true)));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, 4.5);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(value, 0);
    });

    testWidgets('is an adjustable value', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      var value = 3.0;
      await tester.pumpWidget(scene(rating(() => value, (v) => value = v)));
      final node = tester.getSemantics(find.byType(GlassRating));
      expect(
        node,
        containsSemantics(
          label: 'Rating',
          value: '3 of 5 stars',
          increasedValue: '4 of 5 stars',
          decreasedValue: '2 of 5 stars',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.decrease(find.semantics.byLabel('Rating'));
      await tester.pump();
      expect(value, 2);
      handle.dispose();
    });
  });

  group('GlassPinField', () {
    testWidgets('typing fills the boxes and completes', (tester) async {
      await setUpGlass(tester);
      final changes = <String>[];
      final completed = <String>[];
      await tester.pumpWidget(scene(GlassPinField(onChanged: changes.add, onCompleted: completed.add)));
      await tester.tap(find.byType(GlassPinField));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '12');
      await settle(tester);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(completed, isEmpty);
      await tester.enterText(find.byType(EditableText), '123456');
      await settle(tester);
      expect(completed, ['123456']);
      expect(changes.last, '123456');
      // More than fits is dropped.
      await tester.enterText(find.byType(EditableText), '1234567');
      await settle(tester);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '123456');
    });

    testWidgets('takes only digits', (tester) async {
      await setUpGlass(tester);
      final changes = <String>[];
      await tester.pumpWidget(scene(GlassPinField(length: 4, onChanged: changes.add)));
      await tester.tap(find.byType(GlassPinField));
      await tester.enterText(find.byType(EditableText), '1a2 b3');
      await settle(tester);
      expect(changes.last, '123');
    });

    testWidgets('backspace deletes the last character', (tester) async {
      await setUpGlass(tester);
      final changes = <String>[];
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(scene(GlassPinField(controller: controller, onChanged: changes.add)));
      await tester.tap(find.byType(GlassPinField));
      await tester.enterText(find.byType(EditableText), '123');
      await settle(tester);
      // Even with the caret moved, it goes back to the end.
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await settle(tester);
      expect(controller.text, '12');
      expect(changes.last, '12');
      expect(find.text('3'), findsNothing);
    });

    testWidgets('a paste fills every box, replacing a full code', (tester) async {
      await setUpGlass(tester);
      final completed = <String>[];
      var clipboard = '98-76 54';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': clipboard};
        if (call.method == 'Clipboard.hasStrings') return <String, dynamic>{'value': true};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(scene(GlassPinField(onCompleted: completed.add)));
      await tester.tap(find.byType(GlassPinField));
      await tester.pump();
      Future<void> paste() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(tester);
      }

      await paste();
      expect(completed, ['987654']);
      for (final digit in '987654'.split('')) {
        expect(find.text(digit), findsOneWidget);
      }
      clipboard = '111222';
      await paste();
      expect(completed.last, '111222');
    });

    testWidgets('obscure shows dots', (tester) async {
      await setUpGlass(tester);
      await tester.pumpWidget(scene(const GlassPinField(length: 4, obscure: true)));
      await tester.tap(find.byType(GlassPinField));
      await tester.enterText(find.byType(EditableText), '42');
      await settle(tester);
      expect(find.text('4'), findsNothing);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('an error shakes, then rests', (tester) async {
      await setUpGlass(tester);
      Widget field(bool error) => GlassPinField(length: 4, error: error);
      await tester.pumpWidget(scene(field(false)));
      await settle(tester);
      double shift() {
        final transform = tester.widget<Transform>(
          find.descendant(of: find.byType(GlassPinField), matching: find.byType(Transform)).first,
        );
        return transform.transform.getTranslation().x;
      }

      expect(shift(), 0);
      await tester.pumpWidget(scene(field(true)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(shift().abs(), greaterThan(2));
      await settle(tester);
      expect(shift(), 0);
    });

    testWidgets('disabled takes no focus', (tester) async {
      await setUpGlass(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(scene(GlassPinField(focusNode: focus, enabled: false)));
      await tester.tap(find.byType(GlassPinField));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('is a labelled text field', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(scene(const GlassPinField(semanticLabel: 'Verification code')));
      expect(
        tester.getSemantics(find.byType(EditableText)),
        containsSemantics(label: 'Verification code', isTextField: true),
      );
      handle.dispose();
    });
  });

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';

    testWidgets('wheels look right $name', (tester) async {
      await setUpGlass(tester, size: const Size(340, 520), ratio: 2);
      await tester.pumpWidget(
        scene(
          dark: dark,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                child: GlassPicker(
                  items: const ['Apple', 'Banana', 'Cherry', 'Grape', 'Lemon', 'Mango'],
                  initialItem: 2,
                  height: 150,
                  onSelectedItemChanged: (_) {},
                ),
              ),
              const SizedBox(height: 12),
              GlassDatePicker(initialDate: DateTime(2024, 2, 14), height: 150, onDateTimeChanged: (_) {}),
              const SizedBox(height: 12),
              GlassTimePicker(initialTime: DateTime(2024, 2, 14, 9, 41), height: 150, onDateTimeChanged: (_) {}),
            ],
          ),
        ),
      );
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/pickers_wheels_$name.png'));
    });

    testWidgets('inputs look right $name', (tester) async {
      await setUpGlass(tester, size: const Size(360, 300), ratio: 2);
      final typed = TextEditingController(text: '418');
      final wrong = TextEditingController(text: '1234');
      addTearDown(typed.dispose);
      addTearDown(wrong.dispose);
      await tester.pumpWidget(
        scene(
          dark: dark,
          SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassRangeSlider(values: const GlassRange(0.25, 0.7), onChanged: (_) {}),
                const SizedBox(height: 8),
                const GlassRangeSlider(values: GlassRange(0.4, 0.6), onChanged: null),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlassRating(value: 3.5, allowHalf: true, onChanged: (_) {}),
                    const SizedBox(width: 16),
                    const GlassRating(value: 4.3, onChanged: null, size: 16, spacing: 2),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPinField(controller: typed, autofocus: true),
                const SizedBox(height: 12),
                GlassPinField(length: 4, controller: wrong, error: true, obscure: true),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/pickers_inputs_$name.png'));
    });
  }
}

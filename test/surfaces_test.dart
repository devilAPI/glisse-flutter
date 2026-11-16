import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

/// A page with a button that runs [open] with the page's context.
Widget opener(void Function(BuildContext context) open, {bool dark = false}) {
  return scene(
    dark: dark,
    Builder(builder: (context) => GlassButton(onPressed: () => open(context), child: const Text('Open'))),
  );
}

const _photoActions = [
  GlassActionSheetAction(result: 'share', child: Text('Share')),
  GlassActionSheetAction(result: 'duplicate', isDefault: true, child: Text('Duplicate')),
  GlassActionSheetAction(result: 'delete', destructive: true, child: Text('Delete')),
];

List<GlassMenuEntry> _menuItems(List<String> log) => [
  GlassMenuItem(label: const Text('Copy'), icon: const Icon(Icons.copy), onSelected: () => log.add('copy')),
  GlassMenuItem(label: const Text('Share'), icon: const Icon(Icons.ios_share), onSelected: () => log.add('share')),
  GlassMenuItem(label: const Text('Hidden'), enabled: false, onSelected: () => log.add('hidden')),
  const GlassMenuSeparator(),
  GlassMenuItem(
    label: const Text('Delete'),
    icon: const Icon(Icons.delete_outline),
    destructive: true,
    onSelected: () => log.add('delete'),
  ),
];

Widget _tile(String label) => Container(
  width: 120,
  height: 60,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
  child: Text(label),
);

void main() {
  group('action sheet', () {
    Future<Future<String?>> open(WidgetTester tester, {bool dark = false}) async {
      late Future<String?> result;
      await tester.pumpWidget(
        opener(
          dark: dark,
          (context) =>
              result = showGlassActionSheet<String>(
                context: context,
                title: const Text('Photo'),
                message: const Text('What would you like to do with it?'),
                actions: _photoActions,
                cancel: const GlassActionSheetAction(result: 'cancel', child: Text('Cancel')),
              ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      return result;
    }

    testWidgets('returns the chosen action’s result and calls it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      var pressed = 0;
      late Future<String?> result;
      await tester.pumpWidget(
        opener(
          (context) =>
              result = showGlassActionSheet<String>(
                context: context,
                actions: [
                  GlassActionSheetAction(result: 'share', onPressed: () => pressed++, child: const Text('Share')),
                ],
              ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Share'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await settle(tester);
      expect(await result, 'share');
      expect(pressed, 1);
      expect(find.text('Share'), findsNothing);
    });

    testWidgets('cancel returns its result', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final result = await open(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(await result, 'cancel');
    });

    testWidgets('a tap on the scrim dismisses it with null', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final result = await open(tester);
      await tester.tapAt(const Offset(200, 30));
      await settle(tester);
      expect(await result, isNull);
      expect(find.text('Photo'), findsNothing);
    });

    testWidgets('Escape dismisses it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final result = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(await result, isNull);
    });

    testWidgets('a drag across the rows chooses where it is let go', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final result = await open(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.text('Share')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Duplicate')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Delete')));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(await result, 'delete');
    });

    testWidgets('a drag let go off the rows chooses nothing', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final result = await open(tester);
      var done = false;
      unawaited(result.then((_) => done = true));
      final gesture = await tester.startGesture(tester.getCenter(find.text('Share')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Photo')));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(done, isFalse);
      expect(find.text('Share'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
    });

    testWidgets('a second tap while it closes does not pop the page', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final result = await open(tester);
      final second = tester.getCenter(find.text('Delete'));
      await tester.tap(find.text('Share'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(second);
      await settle(tester);
      expect(await result, 'share');
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('sits above the bottom safe area', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      tester.view.padding = const FakeViewPadding(bottom: 68);
      tester.view.viewPadding = const FakeViewPadding(bottom: 68);
      await open(tester);
      final cancel = tester.getRect(find.ancestor(of: find.text('Cancel'), matching: find.byType(Glass)));
      expect(cancel.bottom, lessThanOrEqualTo(600 - 34 - 8 + 0.5));
      expect(cancel.bottom, greaterThan(600 - 34 - 20));
    });

    testWidgets('many actions scroll on a small screen', (tester) async {
      await setUpGlass(tester, size: const Size(320, 300));
      await tester.pumpWidget(
        opener(
          (context) => showGlassActionSheet<int>(
            context: context,
            title: const Text('Pick one'),
            actions: [for (var i = 0; i < 12; i++) GlassActionSheetAction(result: i, child: Text('Action $i'))],
            cancel: const GlassActionSheetAction(child: Text('Cancel')),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.getRect(find.text('Cancel')).bottom, lessThan(300));
    });

    testWidgets('has route and button semantics', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('Actions'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Delete')),
        containsSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('context menu', () {
    Widget menuScene(List<String> log, {Alignment alignment = Alignment.center, bool dark = false}) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: GlassBackdrop(
            background: Stripes(dark: dark),
            child: GlassTheme(
              data: dark ? GlassThemeData.dark() : GlassThemeData.light(),
              child: Align(
                alignment: alignment,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GlassContextMenu(items: _menuItems(log), child: _tile('Photo')),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a long press opens it, and choosing a row calls it and closes', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final log = <String>[];
      await tester.pumpWidget(menuScene(log));
      expect(find.text('Copy'), findsNothing);
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      expect(find.text('Copy'), findsOneWidget);
      // The lifted preview, and the child it stands in for.
      expect(find.text('Photo'), findsNWidgets(2));
      // Below the child, with room there.
      expect(tester.getTopLeft(find.text('Copy')).dy, greaterThan(tester.getBottomLeft(find.text('Photo').first).dy));
      await tester.tap(find.text('Share'));
      await settle(tester);
      expect(log, ['share']);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('a right-click opens it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(menuScene([]));
      await tester.tap(find.text('Photo'), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await settle(tester);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('a plain tap does not open it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(menuScene([]));
      await tester.tap(find.text('Photo'));
      await settle(tester);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('Escape and a tap outside close it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final log = <String>[];
      await tester.pumpWidget(menuScene(log));
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Copy'), findsNothing);

      await tester.longPress(find.text('Photo'));
      await settle(tester);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      expect(find.text('Copy'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('a disabled row does nothing', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final log = <String>[];
      await tester.pumpWidget(menuScene(log));
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      await tester.tap(find.text('Hidden'));
      await settle(tester);
      expect(log, isEmpty);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('the finger that opened it can slide onto a row and choose it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final log = <String>[];
      await tester.pumpWidget(menuScene(log));
      final gesture = await tester.startGesture(tester.getCenter(find.text('Photo')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await settle(tester);
      expect(find.text('Delete'), findsOneWidget);
      // Let go over the preview: nothing chosen, the menu stays.
      await gesture.moveTo(tester.getCenter(find.text('Copy')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Delete')));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(log, ['delete']);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('letting go of the long press over the preview keeps it open', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(menuScene([]));
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('opens above a child near the bottom, and stays on screen', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(menuScene([], alignment: Alignment.bottomRight));
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      final menu = tester.getRect(find.ancestor(of: find.text('Copy'), matching: find.byType(SingleChildScrollView)));
      expect(menu.bottom, lessThan(tester.getTopLeft(find.text('Photo').last).dy));
      expect(menu.right, lessThanOrEqualTo(400));
      expect(menu.left, greaterThanOrEqualTo(0));
    });

    testWidgets('fits a tiny screen', (tester) async {
      await setUpGlass(tester, size: const Size(260, 220));
      await tester.pumpWidget(menuScene([], alignment: Alignment.topLeft));
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final menu = tester.getRect(find.ancestor(of: find.text('Copy'), matching: find.byType(SingleChildScrollView)));
      expect(menu.top, greaterThanOrEqualTo(0));
      expect(menu.bottom, lessThanOrEqualTo(220));
    });

    testWidgets('closing mid-animation and removing the widget while open are safe', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(menuScene([]));
      await tester.longPress(find.text('Photo'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 30));
      // Reopened on its way out.
      await tester.longPress(find.text('Photo').first);
      await settle(tester);
      expect(find.text('Copy'), findsOneWidget);
      await tester.pumpWidget(scene(const Text('Gone')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('a custom preview shows instead of the child', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(
        scene(
          GlassContextMenu(
            items: _menuItems([]),
            previewBuilder: (context) => const SizedBox(width: 200, height: 120, child: Text('Big photo')),
            child: _tile('Photo'),
          ),
        ),
      );
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      expect(find.text('Big photo'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('has menu semantics and a long-press action', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(menuScene([]));
      expect(tester.getSemantics(find.text('Photo')), containsSemantics(hasLongPressAction: true));
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      expect(find.bySemanticsLabel('Menu'), findsOneWidget);
      expect(tester.getSemantics(find.text('Copy')), containsSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });
  });

  group('banner', () {
    testWidgets('drops in under the safe area and goes after its duration', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      tester.view.padding = const FakeViewPadding(top: 94);
      GlassBannerController? banner;
      await tester.pumpWidget(
        opener((context) {
          banner = showGlassBanner(
            context: context,
            title: const Text('Messages'),
            message: const Text('See you at eight?'),
            duration: const Duration(seconds: 3),
          );
        }),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Messages'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Messages')).dy, greaterThan(47));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Messages'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await settle(tester);
      expect(find.text('Messages'), findsNothing);
      expect(banner!.isShowing, isFalse);
    });

    testWidgets('swiping up dismisses it, a small drag down does not', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(
        opener((context) {
          showGlassBanner(context: context, title: const Text('Mail'), duration: const Duration(seconds: 30));
        }),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      final rest = tester.getCenter(find.text('Mail'));
      await tester.drag(find.text('Mail'), const Offset(0, 40));
      await settle(tester);
      expect(find.text('Mail'), findsOneWidget);
      expect(tester.getCenter(find.text('Mail')).dy, closeTo(rest.dy, 1));
      await tester.fling(find.text('Mail'), const Offset(0, -60), 800);
      await settle(tester);
      expect(find.text('Mail'), findsNothing);
    });

    testWidgets('a tap calls onTap and dismisses it; a controller can too', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      var taps = 0;
      GlassBannerController? banner;
      await tester.pumpWidget(
        opener((context) {
          banner = showGlassBanner(
            context: context,
            title: const Text('Reminder'),
            onTap: () => taps++,
            duration: const Duration(seconds: 30),
          );
        }),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tap(find.text('Reminder'));
      await settle(tester);
      expect(taps, 1);
      expect(find.text('Reminder'), findsNothing);

      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Reminder'), findsOneWidget);
      final closed = banner!.closed;
      banner!.dismiss();
      await settle(tester);
      expect(find.text('Reminder'), findsNothing);
      await closed;
    });

    testWidgets('a new banner replaces the last', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      var count = 0;
      final banners = <GlassBannerController>[];
      await tester.pumpWidget(
        opener((context) {
          count++;
          banners.add(showGlassBanner(context: context, title: Text('Banner $count')));
        }),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Banner 1'), findsNothing);
      expect(find.text('Banner 2'), findsOneWidget);
      expect(banners[0].isShowing, isFalse);
      expect(banners[1].isShowing, isTrue);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      expect(find.text('Banner 2'), findsNothing);
    });

    testWidgets('two in one frame: only the second shows', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(
        opener((context) {
          showGlassBanner(context: context, title: const Text('First'));
          showGlassBanner(context: context, title: const Text('Second'));
        }),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('taken down with the app, it counts as gone', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      GlassBannerController? banner;
      await tester.pumpWidget(
        opener((context) {
          banner = showGlassBanner(context: context, title: const Text('Bye'));
        }),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      expect(banner!.isShowing, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('card', () {
    testWidgets('a tappable card is a focusable button', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      var taps = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        scene(
          SizedBox(
            width: 300,
            child: GlassCard(
              title: const Text('Wi-Fi'),
              subtitle: const Text('Home network'),
              focusNode: focus,
              onTap: () => taps++,
              child: const Text('Connected'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Connected'));
      await settle(tester);
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(GlassCard)),
        containsSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 2);
      handle.dispose();
    });

    testWidgets('a card without onTap is not a button', (tester) async {
      await setUpGlass(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        scene(const SizedBox(width: 300, child: GlassCard(title: Text('Battery'), child: Text('82%')))),
      );
      expect(tester.getSemantics(find.byType(GlassCard)), isNot(containsSemantics(isButton: true)));
      expect(find.text('Battery'), findsOneWidget);
      handle.dispose();
    });
  });

  group('disclosure', () {
    testWidgets('keeps its own state when not controlled', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      final changes = <bool>[];
      await tester.pumpWidget(
        scene(
          SizedBox(
            width: 320,
            child: GlassDisclosure(
              title: const Text('Advanced'),
              onExpansionChanged: changes.add,
              child: const Text('Hidden settings'),
            ),
          ),
        ),
      );
      expect(find.text('Hidden settings'), findsNothing);
      final closed = tester.getSize(find.byType(GlassDisclosure)).height;
      await tester.tap(find.text('Advanced'));
      await settle(tester);
      expect(find.text('Hidden settings'), findsOneWidget);
      expect(tester.getSize(find.byType(GlassDisclosure)).height, greaterThan(closed + 10));
      await tester.tap(find.text('Advanced'));
      await settle(tester);
      expect(find.text('Hidden settings'), findsNothing);
      expect(tester.getSize(find.byType(GlassDisclosure)).height, closeTo(closed, 0.5));
      expect(changes, [true, false]);
    });

    testWidgets('a controlled one follows its parent', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      var expanded = false;
      final asked = <bool>[];
      late StateSetter setOuter;
      await tester.pumpWidget(
        scene(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SizedBox(
                width: 320,
                child: GlassDisclosure(
                  title: const Text('Details'),
                  expanded: expanded,
                  onExpansionChanged: asked.add,
                  child: const Text('Body'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Details'));
      await settle(tester);
      expect(asked, [true]);
      expect(find.text('Body'), findsNothing);
      setOuter(() => expanded = true);
      await settle(tester);
      expect(find.text('Body'), findsOneWidget);
      setOuter(() => expanded = false);
      await settle(tester);
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('starts open, and its header reports the expanded state', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        scene(
          const SizedBox(
            width: 320,
            child: GlassDisclosure(title: Text('Notes'), initiallyExpanded: true, child: Text('Body')),
          ),
        ),
      );
      expect(find.text('Body'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Notes')),
        containsSemantics(isButton: true, hasExpandedState: true, isExpanded: true, hasTapAction: true),
      );
      await tester.tap(find.text('Notes'));
      await settle(tester);
      expect(tester.getSemantics(find.text('Notes')), containsSemantics(hasExpandedState: true, isExpanded: false));
      handle.dispose();
    });

    testWidgets('opens from the keyboard', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        scene(
          SizedBox(
            width: 320,
            child: GlassDisclosure(title: const Text('Keys'), focusNode: focus, child: const Text('Body')),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(find.text('Body'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('sits in a list section as a row, matching its tiles', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      await tester.pumpWidget(
        scene(
          const SizedBox(
            width: 320,
            child: GlassListSection(
              children: [
                GlassListTile(title: Text('Name')),
                GlassDisclosure(inset: false, title: Text('More'), child: Text('Body')),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(Glass), findsOneWidget);
      expect(
        tester.getSize(find.byType(GlassDisclosure)).height,
        closeTo(tester.getSize(find.byType(GlassListTile)).height, 0.5),
      );
      expect(tester.getTopLeft(find.text('More')).dx, closeTo(tester.getTopLeft(find.text('Name')).dx, 0.5));
    });

    testWidgets('right to left, the chevron sits at the left', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      await tester.pumpWidget(
        scene(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(width: 320, child: GlassDisclosure(title: Text('More'), child: Text('Body'))),
          ),
        ),
      );
      final glyph = tester.getCenter(find.byType(GlassGlyph));
      expect(glyph.dx, lessThan(tester.getCenter(find.text('More')).dx));
    });
  });

  testWidgets('everything works with reduced motion', (tester) async {
    await setUpGlass(tester, size: const Size(400, 700));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final log = <String>[];
    Future<String?>? sheet;
    await tester.pumpWidget(
      scene(
        Builder(
          builder:
              (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton(
                    onPressed: () => sheet = showGlassActionSheet<String>(context: context, actions: _photoActions),
                    child: const Text('Sheet'),
                  ),
                  GlassButton(
                    onPressed: () => showGlassBanner(context: context, title: const Text('Banner')),
                    child: const Text('Banner'),
                  ),
                  GlassContextMenu(items: _menuItems(log), child: const Text('Hold me')),
                  const SizedBox(width: 300, child: GlassDisclosure(title: Text('More'), child: Text('Body'))),
                ],
              ),
        ),
      ),
    );
    await tester.tap(find.text('Sheet'));
    await settle(tester);
    await tester.tap(find.text('Share'));
    await settle(tester);
    expect(await sheet, 'share');

    await tester.tap(find.text('Banner'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Banner'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Banner'), findsOneWidget);

    await tester.longPress(find.text('Hold me'));
    await tester.pump();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Copy'), findsNothing);
    expect(log, ['copy']);

    await tester.tap(find.text('More'));
    await tester.pump();
    expect(find.text('Body'), findsOneWidget);
    // Open at once: already as tall as it will be.
    final height = tester.getSize(find.byType(GlassDisclosure)).height;
    await settle(tester);
    expect(tester.getSize(find.byType(GlassDisclosure)).height, height);
  });

  testWidgets('tap targets are labelled', (tester) async {
    await setUpGlass(tester, size: const Size(400, 700));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      scene(
        Builder(
          builder:
              (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton(
                    onPressed:
                        () => showGlassActionSheet<String>(
                          context: context,
                          actions: _photoActions,
                          cancel: const GlassActionSheetAction(child: Text('Cancel')),
                        ),
                    child: const Text('Open'),
                  ),
                  SizedBox(width: 300, child: GlassCard(title: const Text('Card'), onTap: () {})),
                  const SizedBox(width: 300, child: GlassDisclosure(title: Text('More'), child: Text('Body'))),
                  GlassContextMenu(items: _menuItems([]), child: const Text('Hold me')),
                ],
              ),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('Open'));
    await settle(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.longPress(find.text('Hold me'));
    await settle(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';

    testWidgets('action sheet looks right $name', (tester) async {
      await setUpGlass(tester, size: const Size(400, 560));
      await tester.pumpWidget(
        opener(
          dark: dark,
          (context) => showGlassActionSheet<String>(
            context: context,
            title: const Text('Photo'),
            message: const Text('This photo will be deleted from all your devices.'),
            actions: _photoActions,
            cancel: const GlassActionSheetAction(child: Text('Cancel')),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      // A finger resting on the second row.
      final gesture = await tester.startGesture(tester.getCenter(find.text('Duplicate')));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/surfaces_action_sheet_$name.png'));
      await gesture.cancel();
    });

    testWidgets('context menu looks right $name', (tester) async {
      await setUpGlass(tester, size: const Size(400, 500));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Material(
            child: GlassBackdrop(
              background: Stripes(dark: dark),
              child: GlassTheme(
                data: dark ? GlassThemeData.dark() : GlassThemeData.light(),
                child: Align(
                  alignment: const Alignment(-0.5, -0.3),
                  child: GlassContextMenu(items: _menuItems([]), child: _tile('Photo')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('Photo'));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/surfaces_context_menu_$name.png'));
    });

    testWidgets('banner, card and disclosure look right $name', (tester) async {
      await setUpGlass(tester, size: const Size(400, 760));
      await tester.pumpWidget(
        scene(
          dark: dark,
          Builder(
            builder: (context) {
              final theme = GlassTheme.of(context);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassButton(
                      onPressed:
                          () => showGlassBanner(
                            context: context,
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                            ),
                            title: const Text('Messages'),
                            message: const Text('Ana: Are we still on for dinner at eight?'),
                            trailing: const Text('now'),
                            duration: const Duration(minutes: 1),
                          ),
                      child: const Text('Open'),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      leading: const Icon(Icons.wifi),
                      title: const Text('Wi-Fi'),
                      subtitle: const Text('Home network'),
                      trailing: GlassGlyph.chevron(color: theme.muted, size: 14),
                      onTap: () {},
                      child: const Text('Connected, secured, 5 GHz.'),
                    ),
                    const SizedBox(height: 12),
                    const GlassDisclosure(
                      leading: Icon(Icons.tune),
                      title: Text('Advanced'),
                      initiallyExpanded: true,
                      child: Text('Proxy, DNS and a private address for this network.'),
                    ),
                    const SizedBox(height: 12),
                    const GlassDisclosure(title: Text('Closed section'), child: Text('Body')),
                    const SizedBox(height: 12),
                    const GlassListSection(
                      children: [
                        GlassListTile(title: Text('Name'), trailing: Text('Home')),
                        GlassDisclosure(
                          inset: false,
                          initiallyExpanded: true,
                          title: Text('Details'),
                          childPadding: EdgeInsets.zero,
                          child: GlassListTile(title: Text('Router'), trailing: Text('192.168.1.1')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/surfaces_misc_$name.png'));
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);
    });
  }
}

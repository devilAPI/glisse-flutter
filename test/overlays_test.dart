import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

/// A page with a button that runs [open] with the page's context.
Widget opener(void Function(BuildContext context) open, {bool dark = false, Widget? extra}) {
  return scene(
    dark: dark,
    Builder(
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        GlassButton(onPressed: () => open(context), child: const Text('Open')),
        if (extra != null) ...[const SizedBox(height: 16), extra],
      ]),
    ),
  );
}

void main() {
  group('dialog', () {
    testWidgets('shows, and an action dismisses it', (tester) async {
      await setUpGlass(tester);
      var deleted = false;
      await tester.pumpWidget(opener((context) => showGlassDialog<void>(
            context: context,
            builder: (context) => GlassAlertDialog(
              title: const Text('Delete photo?'),
              content: const Text('This cannot be undone.'),
              actions: [
                const GlassDialogAction(child: Text('Cancel')),
                GlassDialogAction(destructive: true, onPressed: () => deleted = true, child: const Text('Delete')),
              ],
            ),
          )));
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Delete photo?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(deleted, isTrue);
      expect(find.text('Delete photo?'), findsNothing);
    });

    testWidgets('a tap on the barrier dismisses it, unless told not to', (tester) async {
      await setUpGlass(tester);
      var dismissible = true;
      await tester.pumpWidget(opener((context) => showGlassDialog<void>(
            context: context,
            barrierDismissible: dismissible,
            builder: (context) => const GlassAlertDialog(title: Text('Hello')),
          )));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.text('Hello'), findsNothing);

      dismissible = false;
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('resolves with the popped value', (tester) async {
      await setUpGlass(tester);
      Future<String?>? result;
      await tester.pumpWidget(opener((context) {
        result = showGlassDialog<String>(
          context: context,
          builder: (context) => GlassAlertDialog(
            title: const Text('Pick'),
            actions: [
              GlassDialogAction(
                dismisses: false,
                onPressed: () => Navigator.of(context).pop('yes'),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
      }));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tap(find.text('Yes'));
      await settle(tester);
      expect(await result, 'yes');
    });
  });

  group('sheet', () {
    testWidgets('drags down to dismiss, and springs back from a small drag', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(opener((context) => showGlassSheet<void>(
            context: context,
            builder: (context) => const SizedBox(height: 200, child: Center(child: Text('Sheet body'))),
          )));
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Sheet body'), findsOneWidget);
      final rest = tester.getCenter(find.text('Sheet body'));

      await tester.drag(find.text('Sheet body'), const Offset(0, 30));
      await settle(tester);
      expect(find.text('Sheet body'), findsOneWidget);
      expect(tester.getCenter(find.text('Sheet body')).dy, closeTo(rest.dy, 1));

      await tester.fling(find.text('Sheet body'), const Offset(0, 200), 1500);
      await settle(tester);
      expect(find.text('Sheet body'), findsNothing);
    });

    testWidgets('a tap above it dismisses it', (tester) async {
      await setUpGlass(tester, size: const Size(400, 600));
      await tester.pumpWidget(opener((context) => showGlassSheet<void>(
            context: context,
            builder: (context) => const Text('Sheet body'),
          )));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);
      expect(find.text('Sheet body'), findsNothing);
    });
  });

  group('toast', () {
    testWidgets('dismisses itself after its duration', (tester) async {
      await setUpGlass(tester);
      GlassToastController? toast;
      await tester.pumpWidget(opener((context) {
        toast = showGlassToast(context, message: const Text('Copied'), duration: const Duration(seconds: 2));
      }));
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await settle(tester);
      expect(find.text('Copied'), findsNothing);
      expect(toast!.isShowing, isFalse);
    });

    testWidgets('swiping up dismisses it, and a controller can too', (tester) async {
      await setUpGlass(tester);
      GlassToastController? toast;
      await tester.pumpWidget(opener((context) {
        toast = showGlassToast(context, message: const Text('Saved'), duration: const Duration(seconds: 10));
      }));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.fling(find.text('Saved'), const Offset(0, -60), 800);
      await settle(tester);
      expect(find.text('Saved'), findsNothing);

      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Saved'), findsOneWidget);
      toast!.dismiss();
      await settle(tester);
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('a new toast replaces the last', (tester) async {
      await setUpGlass(tester);
      var count = 0;
      await tester.pumpWidget(opener((context) {
        count++;
        showGlassToast(context, message: Text('Toast $count'));
      }));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Toast 1'), findsNothing);
      expect(find.text('Toast 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
    });
  });

  group('popover', () {
    testWidgets('a tap toggles it and a tap outside closes it', (tester) async {
      await setUpGlass(tester);
      await tester.pumpWidget(scene(GlassPopover(
        popoverBuilder: (context) => const Text('Popover body'),
        child: const Text('Anchor'),
      )));
      await tester.tap(find.text('Anchor'));
      await settle(tester);
      expect(find.text('Popover body'), findsOneWidget);
      // Below the anchor.
      expect(tester.getCenter(find.text('Popover body')).dy, greaterThan(tester.getCenter(find.text('Anchor')).dy));
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.text('Popover body'), findsNothing);

      await tester.tap(find.text('Anchor'));
      await settle(tester);
      await tester.tap(find.text('Anchor'));
      await settle(tester);
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('a controller opens it, and it opens upwards near the bottom', (tester) async {
      await setUpGlass(tester);
      final controller = GlassPopoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GlassPopover(
              controller: controller,
              popoverBuilder: (context) => const Text('Popover body'),
              child: const Text('Anchor'),
            ),
          ),
        ),
      ));
      controller.show();
      await settle(tester);
      expect(find.text('Popover body'), findsOneWidget);
      expect(tester.getCenter(find.text('Popover body')).dy, lessThan(tester.getCenter(find.text('Anchor')).dy));
      controller.hide();
      await settle(tester);
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('tooltip shows on long press', (tester) async {
      await setUpGlass(tester);
      await tester.pumpWidget(scene(const GlassTooltip(message: 'Add to library', child: Text('Plus'))));
      await tester.longPress(find.text('Plus'));
      await settle(tester);
      expect(find.text('Add to library'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Add to library'), findsNothing);
    });
  });

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    testWidgets('dialog looks right $name', (tester) async {
      await setUpGlass(tester, size: const Size(400, 400));
      await tester.pumpWidget(opener(
        dark: dark,
        (context) => showGlassDialog<void>(
          context: context,
          builder: (context) => const GlassAlertDialog(
            title: Text('Allow “Glisse” to use your location?'),
            content: Text('Your location is used to show nearby glass.'),
            actions: [
              GlassDialogAction(child: Text('Don’t Allow')),
              GlassDialogAction(isDefault: true, child: Text('Allow')),
            ],
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/overlay_dialog_$name.png'));
    });

    testWidgets('sheet looks right $name', (tester) async {
      await setUpGlass(tester, size: const Size(400, 500));
      await tester.pumpWidget(opener(
        dark: dark,
        (context) => showGlassSheet<void>(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Share', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Send this glass to someone, or save it for later.'),
              const SizedBox(height: 16),
              GlassButton(variant: GlassButtonVariant.filled, onPressed: () {}, child: const Text('Send')),
              const SizedBox(height: 8),
              GlassButton(onPressed: () {}, child: const Text('Save for later')),
            ],
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/overlay_sheet_$name.png'));
    });

    testWidgets('toast and popover look right $name', (tester) async {
      await setUpGlass(tester, size: const Size(400, 360));
      await tester.pumpWidget(opener(
        dark: dark,
        (context) => showGlassToast(
          context,
          icon: const Icon(Icons.check_circle, color: Colors.green),
          message: const Text('Copied to clipboard'),
          duration: const Duration(minutes: 1),
        ),
        extra: GlassPopover(
          width: 220,
          popoverBuilder: (context) => const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Popover', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('A card of glass that springs out of its anchor.'),
            ],
          ),
          child: const Padding(padding: EdgeInsets.all(8), child: Text('Anchor')),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.tap(find.text('Anchor'));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/overlay_misc_$name.png'));
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);
    });
  }
}

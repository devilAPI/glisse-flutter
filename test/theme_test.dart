import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

void main() {
  Future<Brightness> brightnessUnder(WidgetTester tester, Widget Function(Widget child) wrap) async {
    late Brightness seen;
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      seen = GlassTheme.of(context).brightness;
      return const SizedBox();
    })));
    return seen;
  }

  testWidgets('follows a Material theme', (tester) async {
    final b = await brightnessUnder(
      tester,
      (child) => MaterialApp(theme: ThemeData(brightness: Brightness.dark), home: child),
    );
    expect(b, Brightness.dark);
  });

  testWidgets('follows a Cupertino theme', (tester) async {
    final b = await brightnessUnder(
      tester,
      (child) => CupertinoApp(theme: const CupertinoThemeData(brightness: Brightness.dark), home: child),
    );
    expect(b, Brightness.dark);
  });

  testWidgets('GlassBrightness and GlassTheme win', (tester) async {
    var b = await brightnessUnder(
      tester,
      (child) => MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: GlassBrightness(brightness: Brightness.light, child: child),
      ),
    );
    expect(b, Brightness.light);
    b = await brightnessUnder(
      tester,
      (child) => MaterialApp(home: GlassTheme(data: GlassThemeData.dark(), child: child)),
    );
    expect(b, Brightness.dark);
  });

  testWidgets('falls back to the platform', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final b = await brightnessUnder(
      tester,
      (child) => MediaQuery.fromView(view: tester.view, child: child),
    );
    expect(b, Brightness.dark);
  });

  test('copyWith keeps what it is not given', () {
    final t = GlassThemeData.light().copyWith(fill: const Color(0xFF123456), blur: 7);
    expect(t.fill, const Color(0xFF123456));
    expect(t.blur, 7);
    expect(t.glass, GlassThemeData.light().glass);
    expect(t == GlassThemeData.light().copyWith(fill: const Color(0xFF123456), blur: 7), isTrue);
  });
}

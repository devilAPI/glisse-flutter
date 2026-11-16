import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

/// A busy backdrop, so refraction shows.
class Stripes extends StatelessWidget {
  const Stripes({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StripesPainter(dark), size: Size.infinite);
}

class _StripesPainter extends CustomPainter {
  _StripesPainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? const Color(0xFF15161C) : const Color(0xFFFFF7E0));
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 10, size.height), Paint()..color = const Color(0xFF2050D0));
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 6), Paint()..color = const Color(0xFFE03030));
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => oldDelegate.dark != dark;
}

bool _fontsLoaded = false;

/// Loads Roboto and the Material icons from the Flutter SDK, when it's at
/// hand, so goldens show real text rather than the test font's boxes.
Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('$dir/$name');
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      any = true;
    }
    if (any) await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Loads the shader and fonts, and sizes the test view.
Future<void> setUpGlass(WidgetTester tester, {Size size = const Size(400, 300), double ratio = 2}) async {
  await tester.runAsync(() async {
    await GlassShaders.load();
    await _loadFonts();
  });
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

/// [child] over stripes, themed.
Widget scene(Widget child, {bool dark = false, bool backdrop = true}) {
  final content = GlassTheme(data: dark ? GlassThemeData.dark() : GlassThemeData.light(), child: Center(child: child));
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      child:
          backdrop
              ? GlassBackdrop(background: Stripes(dark: dark), child: content)
              : Stack(children: [Positioned.fill(child: Stripes(dark: dark)), content]),
    ),
  );
}

/// Pumps until nothing is scheduled, or a fixed number of frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (!tester.binding.hasScheduledFrame) break;
  }
}

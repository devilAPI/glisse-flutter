// Renders the gallery for the README: flutter test --update-goldens test/screenshots_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';
import 'package:glisse_example/gallery.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final file = File('$dir/$name');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('gallery ${dark ? 'dark' : 'light'}', (tester) async {
      await tester.runAsync(() async {
        await GlassShaders.load();
        await _loadFonts();
      });
      tester.view.physicalSize = const Size(430, 1400) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: GlassTheme(
          data: dark ? GlassThemeData.dark() : GlassThemeData.light(),
          child: GalleryPage(dark: dark, onToggleTheme: () {}, animateWallpaper: false),
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await expectLater(find.byType(GalleryPage), matchesGoldenFile('../../doc/gallery_${dark ? 'dark' : 'light'}.png'));
    });
  }
}

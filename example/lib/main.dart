import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

import 'gallery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional: glass loads its shader on its own and frosts until it has it.
  await GlassShaders.precache();
  runApp(const GlisseGallery());
}

class GlisseGallery extends StatefulWidget {
  const GlisseGallery({super.key});

  @override
  State<GlisseGallery> createState() => _GlisseGalleryState();
}

class _GlisseGalleryState extends State<GlisseGallery> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glisse for Flutter',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Builder(
        builder: (context) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return GlassTheme(
            data: dark ? GlassThemeData.dark() : GlassThemeData.light(),
            child: GalleryPage(
              dark: dark,
              onToggleTheme: () => setState(() => _mode = dark ? ThemeMode.light : ThemeMode.dark),
            ),
          );
        },
      ),
    );
  }
}

# Glisse gallery

Every widget in [`glisse_flutter`](https://pub.dev/packages/glisse_flutter) over an animated wallpaper. It includes a playground for the bend, dispersion, frost and rim light, a switch between the glass modes, and a magnifier and loupe that float over the whole page.

```sh
flutter run -d chrome   # or linux, macos, windows, android, ios
```

It's live at https://devilapi.github.io/glisse-flutter/.

The smallest app with glass looks like this:

```dart
import 'package:flutter/material.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackdrop(
        background: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFFF5E62), Color(0xFF7B5CFF), Color(0xFF00C6FF)]),
          ),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GlassButton(onPressed: () {}, child: const Text('Continue')),
            const SizedBox(height: 16),
            GlassSwitch(value: _on, semanticLabel: 'Wi-Fi', onChanged: (v) => setState(() => _on = v)),
          ]),
        ),
      ),
    );
  }
}
```

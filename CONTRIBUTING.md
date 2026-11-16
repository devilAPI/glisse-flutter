# Contributing

Bug reports, fixes and new widgets are welcome. Please open an issue first for anything large.

## Set up

You need Flutter 3.27 or newer. CI uses 3.35 on the stable channel.

```sh
git clone https://github.com/devilAPI/glisse-flutter
cd glisse-flutter
flutter pub get
cd example && flutter run   # the gallery, on any platform
```

## Before you send a pull request

CI runs these checks, and so should you:

```sh
dart format --line-length 120 lib test example/lib example/integration_test
flutter analyze
flutter test
```

If you changed how something looks, re-render the goldens with `flutter test --update-goldens`. Look at the PNGs in `test/goldens/` before you commit them. They render with real Roboto when your Flutter SDK has it, so they show what users will see.

The integration tour drives the real gallery on a desktop engine:

```sh
cd example
flutter test integration_test/gallery_test.dart -d linux   # or macos, windows
```

## House style

- Widgets import only `package:flutter/widgets.dart` and the layers beneath it (`services`, `gestures`, `rendering`, `physics`, `scheduler`, `dart:ui`), so they work in any app. The one exception is `theme.dart`, which reads the brightness of Material's `Theme` and of `CupertinoTheme` so it can follow the app. The gallery and the tests may use Material.
- Colours and tuning come from `GlassTheme.of(context)`. Glass comes from `LiquidGlassBox`, `Glass` or `themedGlass(theme)`. Motion uses `GlassSpring`, and every spring respects `MediaQuery.disableAnimations`.
- Each control exposes one labelled semantics node, so its inner `GestureDetector`s set `excludeFromSemantics: true`. Controls take `semanticLabel`, `focusNode` and `autofocus`, and answer the keyboard. A control with a null callback is disabled and shows at 35% opacity.
- Layouts mirror under right-to-left text.
- Nothing calls `setState` or `markNeedsBuild` during a build. Overlay entries update from a post-frame callback.
- Doc comments are short and plain. Each bug fix comes with a test in `test/regressions_test.dart` that fails without it.

See [doc/architecture.md](doc/architecture.md) for how the shader, the backdrop and the modes fit together.

## Licence

By contributing you agree that your work is released under the [MIT License](LICENSE).

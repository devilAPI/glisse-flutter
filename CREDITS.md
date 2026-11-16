# Credits

## Glisse

This package is a Flutter port of [Glisse](https://github.com/0kzh/glisse) ([glisse.kelvinzhang.ca](https://glisse.kelvinzhang.ca)), iOS 26 Liquid Glass for the web, by [Kelvin Zhang](https://kelvinzhang.ca).

Glisse is MIT licensed, `Copyright (c) 2026 Kelvin Zhang`, and that notice is kept in this repository's [LICENSE](LICENSE). The following is Kelvin Zhang's work, carried over from Glisse:

- **The lens.** The bezel profile refracted by Snell's law, the dome lenses and their splay, the chromatic dispersion, the frost, the saturation, the rim light and its glow, and the painted rim and edge line. Glisse renders these with SVG displacement maps. Here they are reimplemented, with the same maths, in one fragment shader: `shaders/glass.frag`.
- **The measurements.** The sizes, paddings, radii, lens specs and colour tokens of the button, switch, slider, segmented control, tab bar, menu and input, which Glisse measured from iOS 26.1.
- **The motion.** The spring constants, the press physics for pointer and touch, the lift of each lens, and the menu's morph.

## Earlier work Glisse builds on

Glisse credits two sources, so this port owes them too:

- Aave's glass for the web.
- The [study of Liquid Glass refraction with CSS and SVG](https://kube.io/blog/liquid-glass-css-svg/) at kube.io.

## Beyond Glisse

The widgets that Glisse doesn't have were written for this port, in the same style and from the same tokens. They are the dialogs, sheets, toasts, popovers, pickers, calendar, context menu, action sheet, banner, dock and magnifiers. The mode switching, the backdrop capture, and the glass-in-glass composition are new as well.

## Third-party material

- [Flutter](https://flutter.dev) and its Dart SDK, BSD 3-Clause.
- The example gallery uses Material Icons, which come with Flutter under the Apache License 2.0.
- The golden tests load Roboto (Apache License 2.0) from the local Flutter SDK when it's there. The font isn't redistributed in this repository.

## Trademarks

Liquid Glass, iOS and macOS are trademarks of Apple Inc. This project isn't affiliated with or endorsed by Apple, or by Kelvin Zhang.

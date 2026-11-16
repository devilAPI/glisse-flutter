# How it works

This guide is for anyone changing the package itself. To use the widgets, see the [README](../README.md) and the [widget catalogue](widgets.md).

## The layers

```
lib/src/foundation   GlassTheme (tokens and tuning), GlassSpring (an analytic damped spring)
lib/src/rendering    the shader binding (lens.dart), the glass render object (liquid_glass.dart),
                     the backdrop capture (backdrop.dart), lenses over a widget's own content
                     (content_lens.dart), shadows, and hit-test padding
lib/src/widgets      every widget, built from the two layers above
shaders/glass.frag   the one fragment shader that draws all glass
```

## The shader

Glisse draws its glass with SVG displacement maps. Flutter has no SVG filters, so `shaders/glass.frag` runs the same maths per fragment. It is a single shader for every kind of glass, and its uniforms choose what to draw:

- **Refraction.** Every pixel within the bezel is displaced along the normal to the rim. The amount comes from Glisse's bezel profile, refracted by Snell's law with Glisse's normaliser. Dome lenses, such as the switch and slider thumbs, add Glisse's dome arc and splay. The sample is taken at `p − clamp(dir·amount, −1, 1)·0.5·reach`, as in Glisse's `refraction.ts`.
- **Dispersion.** The red, green and blue channels are displaced by 1 + 0.2d, 1 + 0.1d and 1 times the amount, so colours split at the rim.
- **Frost.** The frost takes three rings of taps, rotated per pixel by interleaved gradient noise. Their radius is scaled by σ / 0.770, so a frost of σ matches CSS `blur(σ)`. A saturation matrix and the tint follow.
- **Light.** Glisse's rim light is used, with its glow, its rim and its facing term. A shine above zero adds light and one below zero multiplies.
- **Painted rim.** The edge line and the selection rims are drawn here, with Glisse's widths.
- **Magnification.** It is used by the slider, the magnifier and the loupe.

Uniforms are written by `LensDraw.apply` in `lib/src/rendering/lens.dart`. **The order of the floats there must match the declarations in the shader.** It is 70 floats, then the sampler.

The shader is compiled by Flutter's `impellerc` for SkSL (Skia and the web), GLES, Vulkan and Metal. Two portability notes:

- Avoid GLSL reserved words such as `half` as identifiers.
- Impeller's OpenGL ES render targets are upside down, so the shader flips its texture coordinate under `#ifdef IMPELLER_TARGET_OPENGLES`.

## What glass reads: the three modes

A shader can only bend pixels it is given. `RenderLiquidGlass` picks one of three sources (`GlassMode`):

1. **`captured`**: `GlassBackdrop` paints its `background` into its own layer. `_CaptureLayer.addToScene` notices when that layer changed, and copies it with `OffsetLayer.toImageSync` at the device pixel ratio. A `_capturing` guard stops the copy from triggering itself. Glass inside the backdrop draws the copy through the shader, as an image, so this works on every renderer.
2. **`backdropFilter`**: on Impeller, glass pushes a `BackdropFilterLayer` whose filter is `ImageFilter.shader` with our shader. The engine hands the shader the live backdrop texture, so no copy is needed. The texture is either the whole view or, for glass inside glass, the outer glass's layer. The shader works out which from the texture size (`uSize`), compared against the outer glass's rectangle and the screen's size (`uOuter`, `uScreen`). If it can't place the backdrop, it frosts with a cheap 3×3 blur rather than bend the wrong pixels.
3. **`frost`**: a plain `BackdropFilter` blur and saturation, with the tint and rim painted over it. This is the same fallback Glisse uses in browsers without backdrop SVG filters.

`GlassMode.auto` prefers `captured` inside a `GlassBackdrop`, then `backdropFilter` on Impeller, then `frost`.

### Glass in glass

In `captured` mode, inner glass reads the same copy as the outer glass, which doesn't show the outer glass. So inner glass composes what the outer glass would have done:

- The blurs add in quadrature: √(b² + b_outer²).
- The tints alpha-blend.
- The saturations multiply.

The outer glass passes its style down through the `_GlassAncestor` inherited widget.

### Glass that moves without repainting

A scrolling list or a route transition moves glass with a transform, without repainting it, so its refraction would freeze. `RenderLiquidGlass` checks its transform to the backdrop after each frame (`_watch` / `_check`) and repaints when it moved. The refraction can therefore lag the glass by one frame.

## Lenses over a widget's own content

The switch's track, the slider's track, the tab bar's labels and the dock's icons bend their own content, not the page behind it. `content_lens.dart` records that content into an image (`Picture.toImageSync`) and draws it through the shader inside the lens. This needs no backdrop, so these lenses refract on every renderer and in every mode.

## Motion

`GlassSpring` is an analytic damped spring driven by a `Ticker`. It is a `ChangeNotifier`, so widgets rebuild from it with `AnimatedBuilder` or `Listenable.merge`.

- `set(target)` springs to the target, and `jump(value, velocity:)` throws the spring from a point.
- With `reduceMotion`, set from `MediaQuery.disableAnimations`, every spring lands at once and never bounces.

`GlassPressable` carries Glisse's press physics:

| | Grow (px) | Press stiffness / damping | Release stiffness / damping |
| --- | --- | --- | --- |
| Pointer | 6 | 417.6 / 29.2 | 230 / 23.7 |
| Touch | 15 | 515 / 27.3 | 250 / 11.8 |

## Overlays

Overlays are laid out above the page, outside any `GlassTheme` or `GlassBackdrop` the page set. Dialogs, sheets, action sheets, menus, popovers, toasts and banners capture a `GlassOverlayContext` when they open, and wrap their content in it. That carries over the theme, the backdrop, the text style and the text direction, so glass in an overlay still bends the page beneath it.

## Tests

- **Behaviour tests**, one file per area, cover every widget.
- **Goldens** in `test/goldens/` cover every widget in both themes. They are rendered with Roboto from the local SDK. On CI (`CI=true`) a tolerant comparator allows for font differences.
- **`smoke_test.dart`** builds and presses every widget in both themes, in both text directions and in two glass modes. **`a11y_test.dart`** runs Flutter's accessibility guidelines over the same set.
- **`regressions_test.dart`** keeps every bug fixed in review fixed.
- **`example/integration_test/gallery_test.dart`** tours the real gallery on a desktop engine. CI runs it under xvfb on Linux.

## 0.5.2

### Web

* **No more "This page is slowing down" in browsers without WebGL.** LibreWolf ships with WebGL turned off, and without it Flutter draws every pixel on the CPU. There, glass's shader took 17 to 27 seconds a frame. Glass now checks for WebGL once (`GlassShaders.usable`). Without it, glass paints as a plain tint and rim, with no shader, no blurred shadow, no copies and no lenses, and menus don't blur the page behind them. The same page dropped to about 1.5 seconds a frame.
* The gallery's wallpaper drew its glow with a 100-pixel blur, and without WebGL a single full-screen gradient takes 400 ms. Its blobs are now radial gradients. Without WebGL it draws a flat version and shows a banner explaining why the page is slow and how to turn WebGL on. The gallery now runs at about 400 ms a frame there. That's still slow, but nothing stalls for long.

## 0.5.1

### Web

* **The page no longer grinds to a halt after a while.** On the web, every copy of a `GlassBackdrop`'s background is read back from the GPU, and in Firefox that took about half a second for a screenful. A background that kept changing was copied every frame, and the page slowed to two frames a second. Examples are an animated wallpaper, or the gallery's whole-page lenses over a spinner. Now:
  * On the web, a backdrop waits four times as long as its last copy took before copying again, so copying never takes more than about a fifth of the time.
  * On the web below high quality, copies are made at half the display's resolution, a quarter of the pixels.
  * On the web, glass blurs the copy itself on the GPU, instead of reading back a second, frosted copy.

  In Firefox, clicking through the whole gallery for two and a half minutes went from stalls of half a second to two seconds to none longer than about 180 ms.

## 0.5.0

### Web

* **Privacy-hardened browsers no longer get a blank page.** With `privacy.resistFingerprinting`, which LibreWolf turns on by default and Firefox offers, the browser blocks reading pictures back from a canvas. There, CanvasKit fails inside `Picture.toImageSync` and breaks every draw after it, text included. Glass now checks once, on a canvas of its own, whether read-back works (`GlassShaders.canRecordImages`). Where it doesn't, backdrops don't copy, glass frosts the page without a copy, and controls lift without their lens. The 1×1 image the shader binds when it samples nothing is now decoded from bytes rather than drawn, everywhere.
* **No backdrop blur per pane on the web below high quality.** CanvasKit blurs the page again for each `BackdropFilter`. With one per glass pane, scrolling the gallery in frost mode in Firefox managed 83 frames in 20 seconds. Now glass with no copy to bend, on the web below `GlassQuality.high`, lays its tint and lit rim over the page unblurred, and the same scroll draws 1,239 frames. Menus and context menus skip their backdrop blur there too, leaning on their near-opaque surface (`GlassThemeData.blursBackdrops`).
* On the web, a backdrop's shared frosted copy is made at as little as half size, so there are fewer pixels to read back each time the background changes.

## 0.4.0

### Performance

* **Frost from a shared blurred copy.** Glass over a `GlassBackdrop` used to blur the backdrop itself, with 23 texture samples a pixel, and up to 92 near the rim where the colours split. The backdrop now makes one blurred copy per change, shared by every glass that frosts as much (`GlassBackdropController.frosted`), and glass samples it once a pixel, or up to four times at the rim.
* **Glass repaints without its content.** Glass that moves over its backdrop, as in a scrolling list, has to repaint to aim its refraction. Its content now sits behind a repaint boundary of its own and isn't re-recorded. Scrolling the gallery in Firefox spent about 20% less time building frames.
* **Less shader work.** The shader skips the unbent sample where the rim bends fully, and takes one sample instead of three where colours don't split.
* **`GlassQuality`.** `GlassThemeData.quality` is `low`, `medium`, `high` or `auto` (medium on the web and phones, high on desktops). It sets the frost's rings, the colour split, and the resolution of backdrop copies. The gallery's playground has a picker for it.
* The gallery's wallpaper starts still on every platform; an animated background has to be copied every frame.
* On Linux, scrolling the gallery over its animated wallpaper went from 6.7 ms to 6.1 ms raster on average (12.6 to 10.9 ms at the 90th percentile, 20.8 to 17.5 ms at the 99th).

### Controls

* `GlassRangeSlider`'s knobs lift into lenses that magnify the track, as `GlassSlider`'s thumb does.
* `GlassTabBar` and `GlassSegmentedControl` swell and stretch towards the finger as a whole bar, as buttons and toolbars do.

## 0.3.0

The first release on pub.dev.

### Pressing

* Glass presses the same way everywhere: the whole bubble swells and stretches towards a finger. `GlassToolbar`, `GlassButtonGroup` and `GlassStepper` now press as one capsule, as a `GlassButton` does, while the item under the finger lights up. Before, a toolbar item moved inside a still capsule, and button groups and steppers didn't move at all. Rows on a surface, such as list tiles, sidebar items and menu rows, light up as before.

### Lenses

* `GlassLoupeRegion`'s loupe floats in the app's overlay. It follows the finger anywhere on screen, and the region's ancestors no longer clip it.
* In the gallery, a switch floats the magnifier and the loupe over the whole page. They magnify everything on it, glass included, through a second `GlassBackdrop` that copies the page only while they're shown.

### Fixes

* Dragging a slider slowly no longer bogs down the web, where it could bring Firefox to a halt. The slider, switch, segmented control and tab bar recorded their lens content into an image every frame, and on the web each recording waits on a GPU read-back. Now each records once and draws from the same image while it moves. In Firefox on a desktop GPU, a slow slider drag went from about 20 ms a frame to about 11 ms.
* `GlassCalendar` no longer fails an assertion when it gets almost no width, as when a window opens.
* A new test squeezes every widget to zero and near-zero sizes, and fails on anything worse than an overflow.

### Package

* Needs Flutter 3.29 (Dart 3.7) or newer: `ImageFilter.shader` arrived in 3.29.
* Screenshots and the guides ship with the package. The example has a README with a minimal app, and `flutter_lints` is on 6.0.
* A release workflow runs when a version tag is pushed, as `tool/release.sh 0.3.1` does. It checks the version, builds the gallery for the web, Android, Linux, Windows and macOS, and creates the GitHub release with the builds attached. It can also publish to pub.dev; that stays off until it's turned on.

## 0.2.0

### New widgets

* Pickers: `GlassRangeSlider`, `GlassPicker`, `GlassDatePicker`, `GlassTimePicker`, `GlassCalendar`, `GlassColorSwatches`, `GlassKnob`, `GlassRating`, `GlassPinField`.
* Surfaces: `showGlassActionSheet` with `GlassActionSheet`, `GlassContextMenu`, `showGlassBanner`, `GlassCard`, `GlassDisclosure`.
* Extras: `GlassSlideToConfirm`, `GlassAvatar`, `GlassAvatarGroup`.

### Fixes

* `GlassListSection` indents the hairline under a `GlassDisclosure` row with a leading icon, as it does under a `GlassListTile`.
* The gallery no longer throws when its window starts out narrow.
* `GlassSpring.jump` respects `reduceMotion`, so tapped knobs and badges no longer bounce when animations are off.
* Glass inside frosted glass on Impeller bends its backdrop, instead of falling back to a plain blur.
* Glass on Impeller places its backdrop by the size of the view it's in, rather than the app's first view, so it works in multi-view apps.
* A `GlassBackdrop` copies its background only while some glass under it can read the copy. Glass in `frost` or `backdropFilter` mode no longer triggers copies.
* Glass whose backdrop can't be placed, as inside a fading route, frosts with the same Gaussian rings as other glass, instead of a 3×3 box that showed ghost copies at large blurs.
* The rim's bend fades in over one device pixel at any pixel ratio or lens scale.
* `LensSpec.darkStrength` takes effect on dark pages.
* `GlassShaders.load` tries again after a failed load, and reports the real error.
* `LensSpec` has value equality, so a spec built afresh each frame no longer repaints glass or rebuilds what's inside it. The lens-arc cache is bounded.
* Many smaller fixes from review: a context menu removed while open, disclosures and context menus disabled mid-press, a context menu reopened while closing, the rating's arrow keys from a fractional value, and the calendar's `onMonthChanged`.

### Documentation

* New guides: a [widget catalogue](doc/widgets.md) with an example for every widget, [theming](doc/theming.md) and [how it works](doc/architecture.md). The analyzer checks every example.
* An API reference, published with the gallery at https://devilapi.github.io/glisse-flutter/api/.
* [CREDITS.md](CREDITS.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## 0.1.0

First release: a Flutter port of [Glisse](https://github.com/0kzh/glisse)'s Liquid Glass.

### Glass

* One fragment shader runs Glisse's lens per fragment: Snell's-law bezel refraction, dome lenses with splay, chromatic dispersion, frost, saturation, and rim light. It also draws the painted rim and edge line, the selection rims, ink fringing for labels, and magnification.
* Three ways to read the backdrop:
  * `GlassBackdrop` copies its background for the glass above it, on every renderer.
  * Impeller's live backdrop, read through `ImageFilter.shader`. Glass inside glass reads the outer glass's layer here.
  * Frost everywhere else.
* Glass in glass takes on the outer glass's frost and tint.
* Glass that moves without repainting, in a scrolling list or a route transition, follows its backdrop.
* `GlassTheme` holds Glisse's light and dark tokens and the tuning. It follows the app's Material or Cupertino brightness by default.

### Widgets ported from Glisse

`Glass`, `GlassButton`, `GlassSwitch`, `GlassSlider`, `GlassSegmentedControl`, `GlassTabBar`, `GlassMenu`, `GlassInput` and `GlassSearchField` keep Glisse's measurements, springs, press physics, and lifted lenses. On a light page, the lifted lenses also bend the bar and the page behind them.

### New widgets

* Overlays: `showGlassDialog` with `GlassAlertDialog`, `showGlassSheet`, `showGlassToast`, `GlassPopover`, `GlassTooltip`.
* Controls: `GlassCheckbox`, `GlassRadio`, `GlassStepper`, `GlassChip`, `GlassProgressBar`, `GlassProgressRing`, `GlassActivityIndicator`, `GlassPageIndicator`, `GlassBadge`, `GlassButtonGroup`.
* Navigation: `GlassNavigationBar`, `GlassBackButton`, `GlassToolbar`, `GlassListSection` with `GlassListTile`, `GlassSidebar`, `GlassDock`.
* Lenses: `GlassMagnifier`, `GlassLoupeRegion`.

### Quality

* Each control exposes a single labelled semantics node, and keyboard focus and activation work throughout.
* Reduced motion is honoured.
* Goldens cover every widget in both themes.
* A smoke test runs every widget in each theme, text direction and glass mode.
* Regression tests cover the bugs fixed in review.
* An integration tour runs the gallery on a real engine.
* CI builds the gallery for Android, iOS, macOS, Windows, Linux and the web, and deploys the web gallery to GitHub Pages.

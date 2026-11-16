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

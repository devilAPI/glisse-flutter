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

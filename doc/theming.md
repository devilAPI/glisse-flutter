# Theming

Every widget reads its colours and tuning from `GlassTheme.of(context)`. These are Glisse's CSS custom properties (`--lg-*`), with one set for a light page and one for a dark page.

## Following the app

With no `GlassTheme` above them, widgets pick the light or dark set from the first of these that's present:

1. A `GlassBrightness` widget.
2. The app's Material `Theme`.
3. Its `CupertinoTheme`.
4. The platform's brightness.

So in most apps glass follows dark mode with no setup.

```dart
// Tell Glisse which page it's on, without building a theme:
GlassBrightness(brightness: Brightness.dark, child: page)
```

## Your own theme

Start from a preset and change what you need:

```dart
GlassTheme(
  data: GlassThemeData.dark().copyWith(
    fill: const Color(0xFFFF9F0A),  // the accent
    blur: 6,                        // a heavier frost
    glassBend: 2.6,                 // the rim reaches further in
    glassDispersion: 1.0,           // more colour at the rim
  ),
  child: page,
)
```

`GlassThemeData.fallback(brightness)` returns the matching preset.

## Colours

| Token | What it colours | Light | Dark |
| --- | --- | --- | --- |
| `foreground` | Text and icons on glass | black, 88% | white |
| `muted` | Secondary text, placeholders, unselected tabs | grey, 60% | light grey, 60% |
| `glass` | The frost over what glass shows | white, 60% | grey, 62% |
| `glassActive` | Pressed, hovered or focused glass | light grey, 85% | grey, 62% |
| `edge` | The hairline round glass | black, 8% | white, 8% |
| `drop` | Glass's small drop shadow | black, 6% | none |
| `selection` | A tab bar's selection at rest | black, 10% | white, 14.5% |
| `lens`, `lensDrop` | A lifted lens's fill and shadow | | |
| `segmentTrack`, `segmentThumb`, `segmentLabel`, `segmentLens` | The segmented control | | |
| `surface`, `surfaceEdge`, `shadow` | Menus, sheets, dialogs and pickers | near-white, 86% | near-black, 86% |
| `highlight` | A highlighted row | grey, 9% | light grey, 13% |
| `separator` | Lines between rows | grey, 15% | light grey, 16% |
| `destructive` | Actions that delete | `#FF383C` | `#FF4245` |
| `track` | A switch's track when off, and empty stars | grey, 30% | light grey, 30% |
| `rail` | A slider's rail, and a knob's arc | black, 10% | white, 10% |
| `on` | A switch's track when on | `#34C759` | `#30D158` |
| `fill` | The accent: filled buttons, slider fill, checked boxes, selected days | `#0088FF` | `#0091FF` |
| `ring` | The keyboard focus ring | black, 40% | white, 50% |

## Tuning

| Value | What it does | Default |
| --- | --- | --- |
| `blur` | The frost's blur, as a deviation in logical px (as CSS `blur()`) | 3 |
| `saturation` | How much glass saturates what it shows | 1.5 |
| `glassBend` | How far the rim reaches in, as a share of the bezel | 2 |
| `glassDispersion` | How far colours split at the rim. At 1, red bends a fifth further than blue | 0.6 |
| `rimShine` | The brightness of the painted rim | 0.3 light, 0.13 dark |
| `lensShine` | How a lens's rim catches the light: above 0 it brightens, below 0 it darkens | −1.5 light, 1 dark |
| `switchBend`, `sliderBend`, `segmentBend`, `tabBend`, `tabDispersion` | Per-widget overrides, as Glisse's `--lg-*-bend` | Glisse's |
| `textStyle` | The base style of labels on glass | 14px |
| `mode` | How glass reads what's behind it, for glass that doesn't say (see the README) | `GlassMode.auto` |

## One pane at a time

`Glass` takes its own `tint`, `blur`, `saturation`, `bend`, `dispersion`, `rimShine`, `shadow` and `mode`:

```dart
Glass(
  borderRadius: 32,
  padding: const EdgeInsets.all(20),
  tint: const Color(0x33FF2D55),  // a pink frost
  bend: 3,
  child: const Text('Hello'),
)
```

For a fully custom pane, build a `LiquidGlassBox` with a `GlassStyle`.

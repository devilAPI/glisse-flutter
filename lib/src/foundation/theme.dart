import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../rendering/liquid_glass.dart' show GlassMode;

/// How much work glass does to look its best.
enum GlassQuality {
  /// [medium] on the web and on phones, where every frame of glass costs
  /// more, and [high] on desktops.
  auto,

  /// The fewest samples: a one-ring frost, no colour split at the rim, and
  /// backdrop copies at one pixel per logical pixel.
  low,

  /// A two-ring frost and copies at no more than two pixels per logical pixel.
  medium,

  /// Glisse's full look: a three-ring frost, and copies at the display's
  /// resolution, up to three.
  high,
}

/// The colours and tuning every Glisse widget reads, as Glisse's CSS custom
/// properties (`--lg-*`) set them for a light and a dark page.
@immutable
class GlassThemeData {
  /// Creates a theme from every colour and tuning value.
  const GlassThemeData({
    required this.brightness,
    required this.foreground,
    required this.muted,
    required this.glass,
    required this.glassActive,
    required this.edge,
    required this.drop,
    required this.selection,
    required this.lens,
    required this.lensDrop,
    required this.segmentTrack,
    required this.segmentThumb,
    required this.segmentLabel,
    required this.segmentLens,
    required this.surface,
    required this.surfaceEdge,
    required this.shadow,
    required this.highlight,
    required this.separator,
    required this.destructive,
    required this.track,
    required this.rail,
    required this.on,
    required this.fill,
    required this.ring,
    required this.lensShine,
    required this.rimShine,
    this.blur = 3,
    this.saturation = 1.5,
    this.glassBend = 2,
    this.glassDispersion = 0.6,
    this.switchBend,
    this.sliderBend,
    this.segmentBend,
    this.tabBend,
    this.tabDispersion,
    this.textStyle = const TextStyle(fontSize: 14, height: 1.2, letterSpacing: -0.1),
    this.mode = GlassMode.auto,
    this.quality = GlassQuality.auto,
  });

  /// Glisse on a light page.
  factory GlassThemeData.light() => const GlassThemeData(
    brightness: Brightness.light,
    foreground: Color.fromRGBO(0, 0, 0, 0.88),
    muted: Color.fromRGBO(60, 60, 67, 0.6),
    glass: Color.fromRGBO(255, 255, 255, 0.6),
    glassActive: Color.fromRGBO(236, 236, 240, 0.85),
    edge: Color.fromRGBO(0, 0, 0, 0.08),
    drop: Color.fromRGBO(0, 0, 0, 0.06),
    selection: Color.fromRGBO(0, 0, 0, 0.1),
    lens: Color.fromRGBO(0, 0, 0, 0.03),
    lensDrop: Color.fromRGBO(0, 0, 0, 0.11),
    segmentTrack: Color.fromRGBO(118, 118, 128, 0.12),
    segmentThumb: Color.fromRGBO(255, 255, 255, 1),
    segmentLabel: Color.fromRGBO(0, 0, 0, 1),
    segmentLens: Color.fromRGBO(0, 0, 0, 0.03),
    surface: Color.fromRGBO(250, 250, 252, 0.86),
    surfaceEdge: Color.fromRGBO(0, 0, 0, 0.08),
    shadow: Color.fromRGBO(25, 25, 35, 0.12),
    highlight: Color.fromRGBO(60, 60, 67, 0.09),
    separator: Color.fromRGBO(60, 60, 67, 0.15),
    destructive: Color(0xFFFF383C),
    track: Color.fromRGBO(59, 59, 66, 0.3),
    rail: Color.fromRGBO(0, 0, 0, 0.1),
    on: Color(0xFF34C759),
    fill: Color(0xFF0088FF),
    ring: Color.fromRGBO(0, 0, 0, 0.4),
    lensShine: -1.5,
    rimShine: 0.3,
  );

  /// Glisse on a dark page.
  factory GlassThemeData.dark() => const GlassThemeData(
    brightness: Brightness.dark,
    foreground: Color.fromRGBO(255, 255, 255, 1),
    muted: Color.fromRGBO(235, 235, 245, 0.6),
    glass: Color.fromRGBO(40, 40, 40, 0.62),
    glassActive: Color.fromRGBO(70, 70, 70, 0.62),
    edge: Color.fromRGBO(255, 255, 255, 0.08),
    drop: Color(0x00000000),
    selection: Color.fromRGBO(255, 255, 255, 0.145),
    lens: Color.fromRGBO(255, 255, 255, 0.055),
    lensDrop: Color(0x00000000),
    segmentTrack: Color(0x00000000),
    segmentThumb: Color.fromRGBO(235, 235, 245, 0.3),
    segmentLabel: Color.fromRGBO(255, 255, 255, 1),
    segmentLens: Color(0x00000000),
    surface: Color.fromRGBO(28, 28, 31, 0.86),
    surfaceEdge: Color.fromRGBO(255, 255, 255, 0.13),
    shadow: Color.fromRGBO(0, 0, 0, 0.38),
    highlight: Color.fromRGBO(235, 235, 245, 0.13),
    separator: Color.fromRGBO(235, 235, 245, 0.16),
    destructive: Color(0xFFFF4245),
    track: Color.fromRGBO(235, 235, 245, 0.3),
    rail: Color.fromRGBO(255, 255, 255, 0.1),
    on: Color(0xFF30D158),
    fill: Color(0xFF0091FF),
    ring: Color.fromRGBO(255, 255, 255, 0.5),
    lensShine: 1,
    rimShine: 0.13,
  );

  /// Glisse for [brightness].
  factory GlassThemeData.fallback(Brightness brightness) =>
      brightness == Brightness.dark ? GlassThemeData.dark() : GlassThemeData.light();

  /// Whether this theme is for a light or a dark page.
  final Brightness brightness;

  /// Text and icons on glass.
  final Color foreground;

  /// Secondary text: placeholders, unselected tabs, input icons.
  final Color muted;

  /// The frost laid over what glass shows.
  final Color glass;

  /// The frost of pressed, hovered or focused glass.
  final Color glassActive;

  /// The 0.5px line round glass's edge.
  final Color edge;

  /// Glass's small drop shadow.
  final Color drop;

  /// A tab bar's selection at rest.
  final Color selection;

  /// A lifted lens's fill.
  final Color lens;

  /// A lifted lens's shadow.
  final Color lensDrop;

  /// A segmented control's track tint.
  final Color segmentTrack;

  /// A segmented control's thumb.
  final Color segmentThumb;

  /// A segmented control's labels.
  final Color segmentLabel;

  /// A segmented control's lifted lens fill.
  final Color segmentLens;

  /// Menus, sheets and dialogs.
  final Color surface;

  /// The line round a surface.
  final Color surfaceEdge;

  /// A surface's shadow.
  final Color shadow;

  /// A highlighted menu row.
  final Color highlight;

  /// Lines between rows.
  final Color separator;

  /// Actions that delete or can't be undone.
  final Color destructive;

  /// A switch's track when off.
  final Color track;

  /// A slider's rail.
  final Color rail;

  /// A switch's track when on.
  final Color on;

  /// The accent: filled buttons, slider fill, selected tab icons.
  final Color fill;

  /// The focus ring.
  final Color ring;

  /// How a lens's rim catches the light: above 0 it brightens, below 0 it
  /// darkens, as on a light page.
  final double lensShine;

  /// How bright glass's painted rim is.
  final double rimShine;

  /// The frost's blur, a deviation in logical px.
  final double blur;

  /// How much glass saturates what it shows.
  final double saturation;

  /// How far glass's rim reaches in, as a share of its bezel's width.
  final double glassBend;

  /// How far glass's colours split: at 1, red bends a fifth further than blue.
  final double glassDispersion;

  /// Overrides [glassBend] for a switch's lens, as `--lg-switch-bend` does.
  final double? switchBend;

  /// Overrides [glassBend] for a slider's lens, as `--lg-slider-bend` does.
  final double? sliderBend;

  /// Overrides [glassBend] for a segmented control's lens, as `--lg-segment-bend` does.
  final double? segmentBend;

  /// Overrides [glassBend] for a tab bar's lens, as `--lg-tab-bend` does.
  final double? tabBend;

  /// Overrides [glassDispersion] for a tab bar's lens.
  final double? tabDispersion;

  /// The base text style of labels on glass.
  final TextStyle textStyle;

  /// How glass reads what's behind it, for glass that doesn't say.
  final GlassMode mode;

  /// How much work glass does to look its best; see [GlassQuality].
  final GlassQuality quality;

  /// Whether overlays such as menus may blur the page behind them with a
  /// backdrop filter. Not on the web below [GlassQuality.high], where the
  /// browser blurs the page again for each one: they lean on their
  /// near-opaque [surface] there instead.
  bool get blursBackdrops => !kIsWeb || effectiveQuality == GlassQuality.high;

  /// [quality], with [GlassQuality.auto] settled for this platform.
  GlassQuality get effectiveQuality => switch (quality) {
    GlassQuality.auto =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS
          ? GlassQuality.medium
          : GlassQuality.high,
    final other => other,
  };

  /// Whether [brightness] is dark.
  bool get isDark => brightness == Brightness.dark;

  /// A copy with the given fields replaced.
  GlassThemeData copyWith({
    Brightness? brightness,
    Color? foreground,
    Color? muted,
    Color? glass,
    Color? glassActive,
    Color? edge,
    Color? drop,
    Color? selection,
    Color? lens,
    Color? lensDrop,
    Color? segmentTrack,
    Color? segmentThumb,
    Color? segmentLabel,
    Color? segmentLens,
    Color? surface,
    Color? surfaceEdge,
    Color? shadow,
    Color? highlight,
    Color? separator,
    Color? destructive,
    Color? track,
    Color? rail,
    Color? on,
    Color? fill,
    Color? ring,
    double? lensShine,
    double? rimShine,
    double? blur,
    double? saturation,
    double? glassBend,
    double? glassDispersion,
    double? switchBend,
    double? sliderBend,
    double? segmentBend,
    double? tabBend,
    double? tabDispersion,
    TextStyle? textStyle,
    GlassMode? mode,
    GlassQuality? quality,
  }) {
    return GlassThemeData(
      brightness: brightness ?? this.brightness,
      foreground: foreground ?? this.foreground,
      muted: muted ?? this.muted,
      glass: glass ?? this.glass,
      glassActive: glassActive ?? this.glassActive,
      edge: edge ?? this.edge,
      drop: drop ?? this.drop,
      selection: selection ?? this.selection,
      lens: lens ?? this.lens,
      lensDrop: lensDrop ?? this.lensDrop,
      segmentTrack: segmentTrack ?? this.segmentTrack,
      segmentThumb: segmentThumb ?? this.segmentThumb,
      segmentLabel: segmentLabel ?? this.segmentLabel,
      segmentLens: segmentLens ?? this.segmentLens,
      surface: surface ?? this.surface,
      surfaceEdge: surfaceEdge ?? this.surfaceEdge,
      shadow: shadow ?? this.shadow,
      highlight: highlight ?? this.highlight,
      separator: separator ?? this.separator,
      destructive: destructive ?? this.destructive,
      track: track ?? this.track,
      rail: rail ?? this.rail,
      on: on ?? this.on,
      fill: fill ?? this.fill,
      ring: ring ?? this.ring,
      lensShine: lensShine ?? this.lensShine,
      rimShine: rimShine ?? this.rimShine,
      blur: blur ?? this.blur,
      saturation: saturation ?? this.saturation,
      glassBend: glassBend ?? this.glassBend,
      glassDispersion: glassDispersion ?? this.glassDispersion,
      switchBend: switchBend ?? this.switchBend,
      sliderBend: sliderBend ?? this.sliderBend,
      segmentBend: segmentBend ?? this.segmentBend,
      tabBend: tabBend ?? this.tabBend,
      tabDispersion: tabDispersion ?? this.tabDispersion,
      textStyle: textStyle ?? this.textStyle,
      mode: mode ?? this.mode,
      quality: quality ?? this.quality,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GlassThemeData &&
        other.brightness == brightness &&
        other.foreground == foreground &&
        other.muted == muted &&
        other.glass == glass &&
        other.glassActive == glassActive &&
        other.edge == edge &&
        other.drop == drop &&
        other.selection == selection &&
        other.lens == lens &&
        other.lensDrop == lensDrop &&
        other.segmentTrack == segmentTrack &&
        other.segmentThumb == segmentThumb &&
        other.segmentLabel == segmentLabel &&
        other.segmentLens == segmentLens &&
        other.surface == surface &&
        other.surfaceEdge == surfaceEdge &&
        other.shadow == shadow &&
        other.highlight == highlight &&
        other.separator == separator &&
        other.destructive == destructive &&
        other.track == track &&
        other.rail == rail &&
        other.on == on &&
        other.fill == fill &&
        other.ring == ring &&
        other.lensShine == lensShine &&
        other.rimShine == rimShine &&
        other.blur == blur &&
        other.saturation == saturation &&
        other.glassBend == glassBend &&
        other.glassDispersion == glassDispersion &&
        other.switchBend == switchBend &&
        other.sliderBend == sliderBend &&
        other.segmentBend == segmentBend &&
        other.tabBend == tabBend &&
        other.tabDispersion == tabDispersion &&
        other.textStyle == textStyle &&
        other.mode == mode &&
        other.quality == quality;
  }

  @override
  int get hashCode => Object.hashAll([
    brightness, foreground, muted, glass, glassActive, edge, drop, selection, lens, lensDrop, //
    segmentTrack, segmentThumb, segmentLabel, segmentLens, surface, surfaceEdge, shadow, highlight,
    separator, destructive, track, rail, on, fill, ring, lensShine, rimShine, blur, saturation,
    glassBend, glassDispersion, switchBend, sliderBend, segmentBend, tabBend, tabDispersion, textStyle,
    mode, quality,
  ]);
}

/// Sets the [GlassThemeData] for the widgets below it.
///
/// Without one, Glisse widgets follow the ambient brightness: a
/// [GlassBrightness]'s, else the app's Material `Theme`'s, else its
/// `CupertinoTheme`'s, else the platform's.
class GlassTheme extends InheritedWidget {
  /// Applies [data] to [child] and the widgets below it.
  const GlassTheme({super.key, required this.data, required super.child});

  /// The theme the widgets below read.
  final GlassThemeData data;

  /// The nearest [GlassThemeData], or the default for the ambient brightness.
  static GlassThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<GlassTheme>();
    if (theme != null) return theme.data;
    final brightness = _ambientBrightness(context);
    return brightness == Brightness.dark ? _dark : _light;
  }

  static final GlassThemeData _light = GlassThemeData.light();
  static final GlassThemeData _dark = GlassThemeData.dark();

  // The page's brightness: a GlassBrightness's, else the app's Material
  // theme's, else its Cupertino theme's, else the platform's.
  static Brightness _ambientBrightness(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_GlassBrightness>();
    if (inherited != null) return inherited.brightness;
    if (context.findAncestorWidgetOfExactType<Theme>() != null) return Theme.of(context).brightness;
    final cupertino =
        context.findAncestorWidgetOfExactType<CupertinoTheme>() != null
            ? CupertinoTheme.maybeBrightnessOf(context)
            : null;
    if (cupertino != null) return cupertino;
    return MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
  }

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => data != oldWidget.data;
}

/// Lets an app's own theme (such as Material's) tell Glisse which page it
/// is on, without building a full [GlassThemeData].
class GlassBrightness extends StatelessWidget {
  /// Tells the widgets in [child] to use [brightness].
  const GlassBrightness({super.key, required this.brightness, required this.child});

  /// The brightness of the page below.
  final Brightness brightness;

  /// The widgets that follow [brightness].
  final Widget child;

  @override
  Widget build(BuildContext context) => _GlassBrightness(brightness: brightness, child: child);
}

class _GlassBrightness extends InheritedWidget {
  const _GlassBrightness({required this.brightness, required super.child});

  final Brightness brightness;

  @override
  bool updateShouldNotify(_GlassBrightness oldWidget) => brightness != oldWidget.brightness;
}

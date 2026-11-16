import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';

/// A pane of Liquid Glass: it bends what's behind it at its rim, frosts and
/// tints it, and lights its edge, then shows its [child] on top.
///
/// Over a [GlassBackdrop] it bends the backdrop on every platform; on
/// Impeller it bends whatever is behind it; elsewhere it frosts.
class Glass extends StatelessWidget {
  /// Creates a glass pane.
  const Glass({
    super.key,
    this.child,
    this.borderRadius = 24,
    this.padding,
    this.width,
    this.height,
    this.tint,
    this.blur,
    this.saturation,
    this.bend,
    this.dispersion,
    this.rimShine,
    this.shadow = true,
    this.mode = GlassMode.auto,
  });

  /// What the pane shows on top of the glass.
  final Widget? child;

  /// The corners' radius; [double.infinity] for a capsule.
  final double borderRadius;

  /// Space between the glass's edge and [child].
  final EdgeInsetsGeometry? padding;

  /// The pane's width, in logical px; null sizes it to its parent and [child].
  final double? width;

  /// The pane's height, in logical px; null sizes it to its parent and [child].
  final double? height;

  /// The frost's colour, over what the glass shows. Defaults to the theme's glass.
  final Color? tint;

  /// The frost's blur deviation, in logical px.
  final double? blur;

  /// How much the glass saturates what it shows.
  final double? saturation;

  /// How far the rim reaches in for what it shows, as a share of its bezel.
  final double? bend;

  /// How far the colours split at the rim.
  final double? dispersion;

  /// How bright the rim's light is, from 0 to 1.
  final double? rimShine;

  /// Whether to cast the small drop shadow.
  final bool shadow;

  /// How the glass reads what's behind it. [GlassMode.auto] leaves that to
  /// the theme's [GlassThemeData.mode].
  final GlassMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    Widget? content = child;
    if (content != null && padding != null) content = Padding(padding: padding!, child: content);
    if (content != null) {
      content = DefaultTextStyle.merge(
        style: theme.textStyle.copyWith(color: theme.foreground),
        child: IconTheme.merge(data: IconThemeData(color: theme.foreground, size: 20), child: content),
      );
    }
    Widget glass = LiquidGlassBox(
      radius: borderRadius,
      style: GlassStyle(
        tint: tint ?? theme.glass,
        edge: theme.edge,
        drop: shadow ? theme.drop : const Color(0x00000000),
        rimShine: rimShine ?? theme.rimShine,
        blur: blur ?? theme.blur,
        saturation: saturation ?? theme.saturation,
        bend: bend ?? theme.glassBend,
        dispersion: dispersion ?? theme.glassDispersion,
        spec: LensSpec.glass,
        mode: mode,
      ),
      child: content,
    );
    if (width != null || height != null) glass = SizedBox(width: width, height: height, child: glass);
    return glass;
  }
}

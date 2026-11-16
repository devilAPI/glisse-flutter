import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/backdrop.dart';
import '../rendering/shadows.dart';

/// What glass in an overlay takes from the page that opened it: the theme,
/// the backdrop it floats over, and the page's text style.
///
/// Overlays are laid out above the page, outside any [GlassTheme] or
/// [GlassBackdrop] the page set, so each overlay captures them when it opens
/// and gives them to its own content.
class GlassOverlayContext {
  /// Captures what [context] gives glass: its theme, backdrop, text style and text direction.
  GlassOverlayContext.of(BuildContext context)
    : theme = GlassTheme.of(context),
      backdrop = GlassBackdrop.maybeOf(context),
      textStyle = DefaultTextStyle.of(context).style,
      direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

  /// The page's glass theme.
  final GlassThemeData theme;

  /// The page's backdrop, if it has one.
  final GlassBackdropController? backdrop;

  /// The page's text style.
  final TextStyle textStyle;

  /// The page's text direction; left to right if it set none.
  final TextDirection direction;

  /// [child], with what the page gave.
  Widget wrap(Widget child) {
    return Directionality(
      textDirection: direction,
      child: GlassTheme(
        data: theme,
        child: GlassBackdrop.inherit(
          controller: backdrop,
          child: DefaultTextStyle(
            style: textStyle.merge(theme.textStyle).copyWith(color: theme.foreground, decoration: TextDecoration.none),
            child: IconTheme.merge(data: IconThemeData(color: theme.foreground, size: 20), child: child),
          ),
        ),
      ),
    );
  }
}

/// A curve that follows a damped spring from 0 to 1, landing exactly on 1.
class GlassSpringCurve extends Curve {
  /// Creates a curve of a spring with the given [stiffness] and [dampingRatio] (1 is critical damping), run for [duration] seconds.
  GlassSpringCurve({double stiffness = 400, double dampingRatio = 0.8, this.duration = 0.5})
    : _simulation = SpringSimulation(
        SpringDescription(mass: 1, stiffness: stiffness, damping: dampingRatio * 2 * math.sqrt(stiffness)),
        0,
        1,
        0,
      );

  final SpringSimulation _simulation;

  /// The time, in seconds, the curve spans.
  final double duration;

  @override
  double transformInternal(double t) => _simulation.x(t * duration);
}

/// A surface's soft shadow, drawn only outside its rounded rect, as CSS's
/// box-shadow: glass shows no shadow through itself.
class GlassSurfaceShadow extends StatelessWidget {
  /// Creates a shadow cast round a rounded rect of [radius] under [child].
  const GlassSurfaceShadow({
    super.key,
    required this.radius,
    required this.child,
    this.color,
    this.offset = const Offset(0, 12),
    this.blur = 40,
  });

  /// The corner radius, in logical pixels.
  final double radius;

  /// The shadow's colour. Defaults to the theme's shadow colour.
  final Color? color;

  /// How far the shadow is shifted, in logical pixels.
  final Offset offset;

  /// How far the shadow spreads, in logical pixels.
  final double blur;

  /// What the shadow falls behind.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? GlassTheme.of(context).shadow;
    return CustomPaint(painter: _ShadowPainter(radius, color, offset, blur), child: child);
  }
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter(this.radius, this.color, this.offset, this.blur);

  final double radius;
  final Color color;
  final Offset offset;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    paintDropShadow(canvas, roundedRect(Offset.zero & size, radius), color: color, offset: offset, blur: blur);
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.blur != blur;
}

/// The frost of floating surfaces: the glass's own, made a little denser so
/// text on it reads over anything.
Color floatingTint(GlassThemeData theme) => Color.lerp(theme.glass, theme.surface, 0.5)!;

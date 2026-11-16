import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

/// The dot at the foot of a [GlassAvatar].
enum GlassAvatarStatus {
  /// Green.
  online,

  /// Orange.
  away,

  /// Red.
  busy,

  /// No dot.
  none,
}

/// A circle of glass showing a person: their picture, their initials, or an
/// icon, with an optional status dot cut into its rim.
class GlassAvatar extends StatelessWidget {
  const GlassAvatar({
    super.key,
    this.image,
    this.initials,
    this.icon,
    this.size = 40,
    this.status = GlassAvatarStatus.none,
    this.tint,
    this.semanticLabel,
  }) : assert(size > 0);

  /// The picture, covering the circle. Initials or the icon show while it loads.
  final ImageProvider? image;

  /// Up to two letters, such as "AB". A name gives its first and last
  /// initials; one longer word, its first two letters.
  final String? initials;

  /// Shown when there's no picture and no initials. Defaults to a person.
  final Widget? icon;

  /// The circle's diameter.
  final double size;
  final GlassAvatarStatus status;

  /// The glass's frost. Defaults to the theme's.
  final Color? tint;

  /// Defaults to the initials.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final letters = _letters(initials);

    Widget face;
    if (letters != null) {
      face = Text(
        letters,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: theme.textStyle.copyWith(
          color: theme.foreground,
          fontSize: size * 0.38,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      );
    } else if (icon != null) {
      face = IconTheme.merge(data: IconThemeData(color: theme.muted, size: size * 0.5), child: icon!);
    } else {
      face = SizedBox.square(
        dimension: size * 0.62,
        child: CustomPaint(painter: _PersonPainter(theme.muted)),
      );
    }
    Widget content = Center(child: face);
    if (image != null) {
      content = Stack(fit: StackFit.expand, children: [
        content,
        ClipOval(
          child: Image(
            image: image!,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            // Until it loads, or if it fails, the face underneath shows.
            frameBuilder: (context, child, frame, sync) => frame == null && !sync ? const SizedBox.shrink() : child,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      ]);
    }

    Widget avatar = LiquidGlassBox(
      radius: double.infinity,
      style: themedGlass(theme, tint: tint),
      child: SizedBox.square(dimension: size, child: content),
    );

    final dotColor = switch (status) {
      GlassAvatarStatus.online => theme.on,
      GlassAvatarStatus.away => const Color(0xFFFF9F0A),
      GlassAvatarStatus.busy => theme.destructive,
      GlassAvatarStatus.none => null,
    };
    if (dotColor != null) {
      final dot = math.max(8.0, size * 0.26);
      final gap = math.max(1.5, size * 0.05);
      // The dot sits on the rim, at the bottom end.
      final r = size / 2;
      final along = r + r * math.cos(math.pi / 4);
      final center = Offset(rtl ? size - along : along, along);
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          ClipPath(clipper: _CutOutClipper([(center, dot / 2 + gap)]), child: avatar),
          Positioned(
            left: center.dx - dot / 2,
            top: center.dy - dot / 2,
            width: dot,
            height: dot,
            child: DecoratedBox(decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ),
        ],
      );
    }

    final label = semanticLabel ?? letters;
    final statusName = switch (status) {
      GlassAvatarStatus.online => 'Online',
      GlassAvatarStatus.away => 'Away',
      GlassAvatarStatus.busy => 'Busy',
      GlassAvatarStatus.none => null,
    };
    return Semantics(
      container: true,
      image: true,
      label: label,
      value: statusName,
      child: ExcludeSemantics(child: SizedBox.square(dimension: size, child: avatar)),
    );
  }
}

// Two letters at most: a name's first and last initials, else the first two.
String? _letters(String? initials) {
  final words = (initials ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return null;
  final letters = words.length > 1
      ? '${words.first.characters.first}${words.last.characters.first}'
      : words.first.characters.take(2).toString();
  return letters.toUpperCase();
}

/// Clips round holes out of its child: a circle per centre and radius.
class _CutOutClipper extends CustomClipper<Path> {
  _CutOutClipper(this.holes);

  final List<(Offset, double)> holes;

  @override
  Path getClip(Size size) {
    var path = Path()..addRect(Offset.zero & size);
    for (final (center, radius) in holes) {
      path = Path.combine(
          PathOperation.difference, path, Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    }
    return path;
  }

  @override
  bool shouldReclip(_CutOutClipper oldClipper) {
    if (oldClipper.holes.length != holes.length) return true;
    for (var i = 0; i < holes.length; i++) {
      if (oldClipper.holes[i] != holes[i]) return true;
    }
    return false;
  }
}

/// A head and shoulders.
class _PersonPainter extends CustomPainter {
  _PersonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(s / 2, s * 0.34), s * 0.2, paint);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.12, s * 0.94)
        ..cubicTo(s * 0.12, s * 0.66, s * 0.3, s * 0.6, s / 2, s * 0.6)
        ..cubicTo(s * 0.7, s * 0.6, s * 0.88, s * 0.66, s * 0.88, s * 0.94)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PersonPainter oldDelegate) => oldDelegate.color != color;
}

/// A row of overlapping avatars, each cut away where the next one sits, with
/// a glass "+N" after the first [max].
class GlassAvatarGroup extends StatelessWidget {
  const GlassAvatarGroup({
    super.key,
    required this.children,
    this.max = 4,
    this.size = 40,
    this.overlap = 0.3,
    this.semanticLabel,
  })  : assert(max == null || max > 0),
        assert(overlap >= 0 && overlap < 1);

  /// The avatars, usually [GlassAvatar]s; each is laid out [size] across.
  final List<Widget> children;

  /// How many to show before the rest become "+N". Null shows them all.
  final int? max;
  final double size;

  /// How much each avatar covers the one before, as a share of [size].
  final double overlap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final shown = max == null ? children.length : math.min(max!, children.length);
    final rest = children.length - shown;
    final items = <Widget>[
      for (var i = 0; i < shown; i++) children[i],
      if (rest > 0)
        Semantics(
          container: true,
          label: '$rest more',
          child: ExcludeSemantics(
            child: LiquidGlassBox(
              radius: double.infinity,
              style: themedGlass(theme),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: Text(
                    '+$rest',
                    maxLines: 1,
                    style: theme.textStyle.copyWith(
                      color: theme.foreground,
                      fontSize: size * (rest > 99 ? 0.28 : 0.34),
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final step = size * (1 - overlap);
    final gap = math.max(2.0, size * 0.06);
    final width = step * (items.length - 1) + size;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < items.length; i++)
              Positioned(
                left: rtl ? width - size - i * step : i * step,
                top: 0,
                width: size,
                height: size,
                child: i == items.length - 1 || overlap == 0
                    ? items[i]
                    : ClipPath(
                        // Cut where the next one sits, with a gap.
                        clipper: _CutOutClipper([(Offset(size / 2 + (rtl ? -step : step), size / 2), size / 2 + gap)]),
                        child: items[i],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

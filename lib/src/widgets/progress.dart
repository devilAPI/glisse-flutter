import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

/// A progress bar: a 6px rail with the accent filling it, lit along its top
/// like glass. Without a [value] it shows a sweep, for work of unknown length.
class GlassProgressBar extends StatefulWidget {
  /// Creates a progress bar; leave [value] null for an indeterminate one.
  const GlassProgressBar({super.key, this.value, this.color, this.height = 6, this.semanticLabel});

  /// From 0 to 1, or null while unknown.
  final double? value;

  /// The fill's colour. Defaults to the theme's accent.
  final Color? color;

  /// The rail's height, in logical pixels.
  final double height;

  /// Names the control for assistive technology.
  final String? semanticLabel;

  @override
  State<GlassProgressBar> createState() => _GlassProgressBarState();
}

class _GlassProgressBarState extends State<GlassProgressBar> with TickerProviderStateMixin {
  late final GlassSpring _progress = GlassSpring(
    vsync: this,
    value: widget.value ?? 0,
    stiffness: 180,
    damping: 26,
  );
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.value == null) _sweep.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) {
      _progress.set(widget.value!.clamp(0.0, 1.0));
      if (_sweep.isAnimating) _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final value = widget.value;
    return Semantics(
      label: widget.semanticLabel,
      value: value == null ? null : '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(
            rail: theme.rail,
            fill: widget.color ?? theme.fill,
            progress: _progress,
            sweep: value == null ? _sweep : null,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.rail, required this.fill, required this.progress, required this.sweep})
      : super(repaint: Listenable.merge([progress, if (sweep != null) sweep]));

  final Color rail;
  final Color fill;
  final GlassSpring progress;
  final Animation<double>? sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(track, Paint()..color = rail);
    canvas.save();
    canvas.clipRRect(track);
    late Rect bar;
    if (sweep != null) {
      // A third of the rail, sweeping across with an ease in and out.
      final t = Curves.easeInOut.transform(sweep!.value);
      final width = size.width * 0.32;
      final left = -width + (size.width + width) * t;
      bar = Rect.fromLTWH(left, 0, width, size.height);
    } else {
      final v = progress.value.clamp(0.0, 1.0);
      if (v <= 0) {
        canvas.restore();
        return;
      }
      // Never thinner than a dot, so a sliver of progress still shows round.
      bar = Rect.fromLTWH(0, 0, math.max(size.height, size.width * v), size.height);
    }
    final pill = RRect.fromRectAndRadius(bar, r);
    canvas.drawRRect(pill, Paint()..color = fill);
    // The light along its top, as on glass.
    canvas.drawRRect(
      pill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59FFFFFF), Color(0x00FFFFFF), Color(0x14000000)],
          stops: [0, 0.55, 1],
        ).createShader(bar),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.rail != rail || oldDelegate.fill != fill || oldDelegate.sweep != sweep;
}

/// iOS's activity indicator: spokes round a centre, the brightest one
/// turning, each fading behind it.
class GlassActivityIndicator extends StatefulWidget {
  /// Creates an activity indicator of [spokes] spokes.
  const GlassActivityIndicator({super.key, this.radius = 10, this.color, this.animating = true, this.spokes = 8});

  /// The size of the indicator, from centre to tip, in logical pixels.
  final double radius;

  /// Defaults to the theme's muted colour.
  final Color? color;

  /// Whether the spokes turn.
  final bool animating;

  /// How many spokes it has.
  final int spokes;

  @override
  State<GlassActivityIndicator> createState() => _GlassActivityIndicatorState();
}

class _GlassActivityIndicatorState extends State<GlassActivityIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    if (widget.animating) _turn.repeat();
  }

  @override
  void didUpdateWidget(GlassActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !_turn.isAnimating) _turn.repeat();
    if (!widget.animating && _turn.isAnimating) _turn.stop();
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final color = widget.color ?? (theme.isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43));
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.radius * 2,
        child: CustomPaint(painter: _SpokesPainter(color: color, spokes: widget.spokes, turn: _turn)),
      ),
    );
  }
}

class _SpokesPainter extends CustomPainter {
  _SpokesPainter({required this.color, required this.spokes, required this.turn}) : super(repaint: turn);

  final Color color;
  final int spokes;
  final Animation<double> turn;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = size.center(Offset.zero);
    // Steps from spoke to spoke, as UIActivityIndicatorView does, rather than gliding.
    final head = (turn.value * spokes).floor();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * (spokes > 8 ? 0.16 : 0.22);
    for (var i = 0; i < spokes; i++) {
      final age = (head - i) % spokes;
      final alpha = 1 - 0.85 * age / (spokes - 1);
      paint.color = color.withValues(alpha: color.a * alpha);
      final angle = -math.pi / 2 + 2 * math.pi * i / spokes;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + direction * radius * 0.48, center + direction * radius * 0.92, paint);
    }
  }

  @override
  bool shouldRepaint(_SpokesPainter oldDelegate) => oldDelegate.color != color || oldDelegate.spokes != spokes;
}

/// A ring of progress on a disc of glass.
class GlassProgressRing extends StatefulWidget {
  /// Creates a progress ring showing [value].
  const GlassProgressRing(
      {super.key, required this.value, this.size = 36, this.strokeWidth = 4, this.color, this.child});

  /// From 0 to 1.
  final double value;

  /// The disc's width and height, in logical pixels.
  final double size;

  /// The ring's thickness, in logical pixels.
  final double strokeWidth;

  /// The ring's colour. Defaults to the theme's accent.
  final Color? color;

  /// Shown in the middle, such as a stop glyph or a percentage.
  final Widget? child;

  @override
  State<GlassProgressRing> createState() => _GlassProgressRingState();
}

class _GlassProgressRingState extends State<GlassProgressRing> with SingleTickerProviderStateMixin {
  late final GlassSpring _progress = GlassSpring(vsync: this, value: widget.value, stiffness: 180, damping: 26);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress.set(widget.value.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return Semantics(
      value: '${(widget.value.clamp(0.0, 1.0) * 100).round()}%',
      child: LiquidGlassBox(
        radius: double.infinity,
        style: themedGlass(theme),
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              rail: theme.rail,
              fill: widget.color ?? theme.fill,
              strokeWidth: widget.strokeWidth,
              progress: _progress,
            ),
            child: widget.child == null
                ? null
                : Center(
                    child: DefaultTextStyle.merge(
                      style: theme.textStyle.copyWith(color: theme.foreground, fontSize: widget.size * 0.28),
                      child: IconTheme.merge(
                        data: IconThemeData(color: theme.foreground, size: widget.size * 0.4),
                        child: widget.child!,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.rail, required this.fill, required this.strokeWidth, required this.progress})
      : super(repaint: progress);

  final Color rail;
  final Color fill;
  final double strokeWidth;
  final GlassSpring progress;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2 + size.width * 0.12;
    final rect = (Offset.zero & size).deflate(inset);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, stroke..color = rail);
    final v = progress.value.clamp(0.0, 1.0);
    if (v > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * v, false, stroke..color = fill);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.rail != rail || oldDelegate.fill != fill || oldDelegate.strokeWidth != strokeWidth;
}

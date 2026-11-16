import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/hit_padding.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';
import 'pressable.dart';

const double _box = 22;

/// A checkbox of glass: a 22px rounded square that fills with the accent and
/// draws a white tick in when checked. With [tristate], `null` shows a dash.
class GlassCheckbox extends StatefulWidget {
  const GlassCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.activeColor,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(tristate || value != null);

  final bool? value;

  /// Null disables the checkbox.
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final Color? activeColor;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassCheckbox> createState() => _GlassCheckboxState();
}

class _GlassCheckboxState extends State<GlassCheckbox> with TickerProviderStateMixin {
  // How far the box has filled, and how far the tick has drawn.
  late final GlassSpring _fill = GlassSpring(vsync: this, value: _on ? 1 : 0, stiffness: 900, damping: 60);
  late final GlassSpring _draw = GlassSpring(vsync: this, value: _on ? 1 : 0, stiffness: 420, damping: 36);
  late final Listenable _motion = Listenable.merge([_fill, _draw]);

  bool get _on => widget.value != false;
  bool get _enabled => widget.onChanged != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _fill.reduceMotion = reduce;
    _draw.reduceMotion = reduce;
  }

  @override
  void didUpdateWidget(GlassCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _fill.set(_on ? 1 : 0);
      // A new mark draws in from nothing; an old one wipes out quickly.
      if (_on && oldWidget.value != false) _draw.set(0, instant: true);
      _draw.set(_on ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    _draw.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_enabled) return;
    final next = switch (widget.value) {
      false => true,
      true => widget.tristate ? null : false,
      null => false,
    };
    widget.onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final active = widget.activeColor ?? theme.fill;
    final mixed = widget.value == null;
    Widget box = AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final t = _fill.value.clamp(0.0, 1.0);
        return LiquidGlassBox(
          radius: 7,
          style: themedGlass(theme, tint: Color.lerp(theme.glass, active, t)),
          child: SizedBox.square(
            dimension: _box,
            child: CustomPaint(
              painter:
                  _MarkPainter(progress: _draw.value, dash: mixed, opacity: t, outline: _outline(theme, t), radius: 7),
            ),
          ),
        );
      },
    );
    box = GlassPressable(enabled: _enabled, child: box);
    box = GestureDetector(behavior: HitTestBehavior.opaque, onTap: _enabled ? _toggle : null, child: box);
    box = HitPadding(padding: const EdgeInsets.all(11), child: box);
    return Semantics(
      checked: widget.value == true,
      mixed: mixed,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _toggle : null,
      child: GlassFocusable(
        enabled: _enabled,
        onActivate: _toggle,
        radius: 7,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        child: Opacity(opacity: _enabled ? 1 : 0.35, child: box),
      ),
    );
  }
}

/// The ring round an empty box or circle, so it reads on light glass; it
/// fades as the accent fills it.
Color _outline(GlassThemeData theme, double fill) {
  final base = theme.foreground.withValues(alpha: theme.isDark ? 0.32 : 0.24);
  return base.withValues(alpha: base.a * (1 - fill));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.progress,
    required this.dash,
    required this.opacity,
    required this.outline,
    required this.radius,
  });

  final double progress;
  final bool dash;
  final double opacity;
  final Color outline;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    _paintOutline(canvas, size, outline, radius);
    if (progress <= 0.001 || opacity <= 0.001) return;
    final s = size.width / _box;
    final path = dash
        ? (Path()
          ..moveTo(6.5 * s, 11 * s)
          ..lineTo(15.5 * s, 11 * s))
        : (Path()
          ..moveTo(6 * s, 11.5 * s)
          ..lineTo(9.6 * s, 15 * s)
          ..lineTo(16.2 * s, 7.2 * s));
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_trim(path, progress.clamp(0.0, 1.0)), paint);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dash != dash ||
      oldDelegate.opacity != opacity ||
      oldDelegate.outline != outline;
}

void _paintOutline(Canvas canvas, Size size, Color color, double radius) {
  if (color.a <= 0.001) return;
  final rect = (Offset.zero & size).deflate(0.75);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.75)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color,
  );
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => _paintOutline(canvas, size, color, size.width / 2);

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) => oldDelegate.color != color;
}

/// The first [t] of [path]'s length.
Path _trim(Path path, double t) {
  final out = Path();
  final metrics = path.computeMetrics().toList();
  final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
  var left = total * t;
  for (final ui.PathMetric metric in metrics) {
    if (left <= 0) break;
    out.addPath(metric.extractPath(0, left.clamp(0.0, metric.length)), Offset.zero);
    left -= metric.length;
  }
  return out;
}

/// A radio button of glass: a 22px circle that fills with the accent and
/// springs a white dot in when selected.
class GlassRadio<T> extends StatefulWidget {
  const GlassRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.activeColor,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final T value;
  final T? groupValue;

  /// Null disables the radio.
  final ValueChanged<T>? onChanged;
  final Color? activeColor;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassRadio<T>> createState() => _GlassRadioState<T>();
}

class _GlassRadioState<T> extends State<GlassRadio<T>> with TickerProviderStateMixin {
  late final GlassSpring _fill = GlassSpring(vsync: this, value: _selected ? 1 : 0, stiffness: 900, damping: 60);
  // Underdamped, so the dot pops past its size and settles.
  late final GlassSpring _dot = GlassSpring(vsync: this, value: _selected ? 1 : 0, stiffness: 520, damping: 22);
  late final Listenable _motion = Listenable.merge([_fill, _dot]);

  bool get _selected => widget.value == widget.groupValue;
  bool get _enabled => widget.onChanged != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _fill.reduceMotion = reduce;
    _dot.reduceMotion = reduce;
  }

  @override
  void didUpdateWidget(GlassRadio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fill.set(_selected ? 1 : 0);
    _dot.set(_selected ? 1 : 0);
  }

  @override
  void dispose() {
    _fill.dispose();
    _dot.dispose();
    super.dispose();
  }

  void _select() {
    if (_enabled && !_selected) widget.onChanged!(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final active = widget.activeColor ?? theme.fill;
    Widget circle = AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final t = _fill.value.clamp(0.0, 1.0);
        final dot = _dot.value.clamp(0.0, 1.4);
        return LiquidGlassBox(
          radius: double.infinity,
          style: themedGlass(theme, tint: Color.lerp(theme.glass, active, t)),
          child: SizedBox.square(
            dimension: _box,
            child: CustomPaint(
              painter: _OutlinePainter(_outline(theme, t)),
              child: Center(
                child: Container(
                  width: 8 * dot,
                  height: 8 * dot,
                  decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        );
      },
    );
    circle = GlassPressable(enabled: _enabled, child: circle);
    circle = GestureDetector(behavior: HitTestBehavior.opaque, onTap: _enabled ? _select : null, child: circle);
    circle = HitPadding(padding: const EdgeInsets.all(11), child: circle);
    return Semantics(
      checked: _selected,
      inMutuallyExclusiveGroup: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _select : null,
      child: GlassFocusable(
        enabled: _enabled,
        onActivate: _select,
        radius: _box / 2,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        child: Opacity(opacity: _enabled ? 1 : 0.35, child: circle),
      ),
    );
  }
}

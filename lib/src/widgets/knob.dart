import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

// The arc runs clockwise from the lower left to the lower right, through the top.
const double _start = 0.75 * math.pi;
const double _sweep = 1.5 * math.pi;
const double _stroke = 4;
const double _gap = 4;
// How far a straight drag goes to cross the whole range.
const double _dragRange = 200;

/// A rotary dial of glass with an arc round it, filled with the accent up to
/// its value.
///
/// Drag up or right to turn it up, or drag round its rim; a scroll wheel and
/// the arrow keys turn it too.
class GlassKnob extends StatefulWidget {
  /// Creates a knob; [size] must be at least 32.
  const GlassKnob({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.size = 64,
    this.activeColor,
    this.child,
    this.semanticLabel,
    this.semanticFormatter,
    this.focusNode,
    this.autofocus = false,
  })  : assert(divisions == null || divisions > 0),
        assert(size >= 32);

  /// The current value, from [min] to [max].
  final double value;

  /// Called as the value changes. Null disables the knob.
  final ValueChanged<double>? onChanged;

  /// The value at the arc's start.
  final double min;

  /// The value at the arc's end.
  final double max;

  /// Snaps the value to this many equal steps, if set.
  final int? divisions;

  /// Called with the value when a drag starts.
  final ValueChanged<double>? onChangeStart;

  /// Called with the value when a drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// The knob's diameter, arc included.
  final double size;

  /// The arc's fill. Defaults to the theme's accent.
  final Color? activeColor;

  /// Shown in the middle of the dial, such as the value.
  final Widget? child;

  /// Names the control for assistive technology.
  final String? semanticLabel;

  /// How a screen reader reads a value. Defaults to a percentage of the range.
  final String Function(double value)? semanticFormatter;

  /// The control's focus node, to drive or watch its focus.
  final FocusNode? focusNode;

  /// Whether it takes focus when first built.
  final bool autofocus;

  @override
  State<GlassKnob> createState() => _GlassKnobState();
}

class _GlassKnobState extends State<GlassKnob> with TickerProviderStateMixin {
  late final GlassSpring _shown = GlassSpring(vsync: this, value: _progress, stiffness: 600, damping: 50);
  late final GlassSpring _lift = GlassSpring(vsync: this, stiffness: 900, damping: 50);
  late final Listenable _motion = Listenable.merge([_shown, _lift]);

  bool _focused = false;
  bool _dragging = false;
  // While dragging: the unsnapped progress, and where the pointer last was.
  double _raw = 0;
  Offset _last = Offset.zero;
  bool _circular = false;
  // The last value sent, so steps between rebuilds add up.
  late double _latest = widget.value;

  bool get _enabled => widget.onChanged != null && widget.max > widget.min;

  double get _progress => _progressOf(widget.value);

  double _progressOf(double value) {
    if (widget.max <= widget.min) return 0;
    return ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  }

  double get _step => widget.divisions != null ? 1 / widget.divisions! : 1 / 20;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shown.reduceMotion = reduce;
    _lift.reduceMotion = reduce;
  }

  @override
  void didUpdateWidget(GlassKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    _latest = widget.value;
    // A drag follows the finger; other changes ease.
    _shown.set(_progress, instant: _dragging);
    if (!_enabled && _dragging) {
      _dragging = false;
      _lift.set(0);
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    _lift.dispose();
    super.dispose();
  }

  double _snap(double progress) {
    progress = progress.clamp(0.0, 1.0);
    final divisions = widget.divisions;
    if (divisions != null) progress = (progress * divisions).round() / divisions;
    return widget.min + progress * (widget.max - widget.min);
  }

  void _emit(double value) {
    if (value == _latest) return;
    _latest = value;
    widget.onChanged?.call(value);
  }

  Offset get _center => Offset(widget.size / 2, widget.size / 2);

  double _angleOf(Offset local) {
    final d = local - _center;
    return math.atan2(d.dy, d.dx);
  }

  void _dragStart(DragStartDetails details) {
    if (!_enabled || _dragging) return;
    _dragging = true;
    _raw = _progressOf(_latest);
    _last = details.localPosition;
    // From near the rim it turns with the finger; from the middle, it slides.
    final dial = widget.size / 2 - _stroke - _gap;
    _circular = (details.localPosition - _center).distance > dial * 0.55;
    _lift.set(1);
    widget.onChangeStart?.call(widget.value);
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final at = details.localPosition;
    if (_circular) {
      var turn = _angleOf(at) - _angleOf(_last);
      if (turn > math.pi) turn -= 2 * math.pi;
      if (turn < -math.pi) turn += 2 * math.pi;
      // Too near the middle, the angle jumps about; ignore it there.
      if ((at - _center).distance > 6) _raw = (_raw + turn / _sweep).clamp(0.0, 1.0);
    } else {
      final forward = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
      final moved = at - _last;
      _raw = (_raw + (moved.dx * forward - moved.dy) / _dragRange).clamp(0.0, 1.0);
    }
    _last = at;
    _emit(_snap(_raw));
  }

  void _dragEnd([DragEndDetails? details]) {
    if (!_dragging) return;
    _dragging = false;
    _lift.set(0);
    widget.onChangeEnd?.call(_latest);
  }

  void _nudge(double steps) {
    if (!_enabled) return;
    final value = _snap(_progressOf(_latest) + steps * _step);
    widget.onChangeStart?.call(widget.value);
    _emit(value);
    widget.onChangeEnd?.call(value);
  }

  void _jump(double progress) {
    if (!_enabled) return;
    final value = _snap(progress);
    widget.onChangeStart?.call(widget.value);
    _emit(value);
    widget.onChangeEnd?.call(value);
  }

  void _scroll(PointerSignalEvent event) {
    if (!_enabled || event is! PointerScrollEvent) return;
    // Claimed, so a list round the knob doesn't scroll too.
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta;
      final amount = delta.dy.abs() >= delta.dx.abs() ? -delta.dy : delta.dx;
      if (amount != 0) _nudge(amount.sign);
    });
  }

  String _describe(double value) {
    final formatter = widget.semanticFormatter;
    if (formatter != null) return formatter(value);
    return '${(_progressOf(value) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final size = widget.size;
    final dial = size - 2 * (_stroke + _gap);
    final accent = widget.activeColor ?? theme.fill;

    Widget knob = AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final progress = _shown.value.clamp(0.0, 1.0);
        return CustomPaint(
          painter: _ArcPainter(
            progress: progress,
            rail: theme.rail,
            fill: accent,
            focus: _focused ? theme.ring : null,
          ),
          child: Center(
            child: Transform.scale(
              scale: 1 + 0.05 * _lift.value,
              child: LiquidGlassBox(
                radius: double.infinity,
                style: themedGlass(theme, tint: _dragging ? theme.glassActive : theme.glass),
                child: SizedBox.square(
                  dimension: dial,
                  child: CustomPaint(
                    foregroundPainter: _DotPainter(angle: _start + progress * _sweep, color: theme.foreground),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child == null
          ? null
          : Center(
              child: DefaultTextStyle.merge(
                style: theme.textStyle.copyWith(color: theme.foreground, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                child: widget.child!,
              ),
            ),
    );
    knob = SizedBox.square(dimension: size, child: knob);
    knob = Listener(
      onPointerSignal: _scroll,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onVerticalDragStart: _enabled ? _dragStart : null,
        onVerticalDragUpdate: _enabled ? _dragUpdate : null,
        onVerticalDragEnd: _enabled ? _dragEnd : null,
        onVerticalDragCancel: _enabled ? _dragEnd : null,
        onHorizontalDragStart: _enabled ? _dragStart : null,
        onHorizontalDragUpdate: _enabled ? _dragUpdate : null,
        onHorizontalDragEnd: _enabled ? _dragEnd : null,
        onHorizontalDragCancel: _enabled ? _dragEnd : null,
        child: knob,
      ),
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    knob = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _NudgeIntent(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _NudgeIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(rtl ? -1 : 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(rtl ? 1 : -1),
        const SingleActivator(LogicalKeyboardKey.pageUp): const _NudgeIntent(5),
        const SingleActivator(LogicalKeyboardKey.pageDown): const _NudgeIntent(-5),
        const SingleActivator(LogicalKeyboardKey.home): const _JumpIntent(0),
        const SingleActivator(LogicalKeyboardKey.end): const _JumpIntent(1),
      },
      actions: <Type, Action<Intent>>{
        _NudgeIntent: CallbackAction<_NudgeIntent>(onInvoke: (intent) {
          _nudge(intent.steps);
          return null;
        }),
        _JumpIntent: CallbackAction<_JumpIntent>(onInvoke: (intent) {
          _jump(intent.progress);
          return null;
        }),
      },
      child: knob,
    );
    final progress = _progress;
    return Semantics(
      slider: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: _describe(widget.value.clamp(math.min(widget.min, widget.max), math.max(widget.min, widget.max))),
      increasedValue: _describe(_snap(progress + _step)),
      decreasedValue: _describe(_snap(progress - _step)),
      onIncrease: _enabled ? () => _nudge(1) : null,
      onDecrease: _enabled ? () => _nudge(-1) : null,
      child: Opacity(opacity: _enabled ? 1 : 0.35, child: ExcludeSemantics(child: knob)),
    );
  }
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.steps);

  final double steps;
}

class _JumpIntent extends Intent {
  const _JumpIntent(this.progress);

  final double progress;
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.rail, required this.fill, required this.focus});

  final double progress;
  final Color rail;
  final Color fill;
  final Color? focus;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, paint..color = rail);
    if (progress > 0.001) canvas.drawArc(rect, _start, _sweep * progress, false, paint..color = fill);
    if (focus != null) {
      canvas.drawCircle(
        center,
        size.shortestSide / 2 + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focus!,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.rail != rail ||
      oldDelegate.fill != fill ||
      oldDelegate.focus != focus;
}

/// The small dot on the dial that points at the value.
class _DotPainter extends CustomPainter {
  _DotPainter({required this.angle, required this.color});

  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final dot = math.max(2.5, size.shortestSide * 0.06);
    final reach = size.shortestSide / 2 - dot - 4;
    canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * reach, dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => oldDelegate.angle != angle || oldDelegate.color != color;
}

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/content_lens.dart';
import '../rendering/shadows.dart';

// Sizes from GlassSlider.
const double _height = 40;
const double _trackTop = 17;
const double _trackHeight = 6;
const double _thumbWidth = 60;
const double _thumbHeight = 40;
const double _inset = 18;
// A knob rests at 60% of the slider's thumb and grows a little when held.
const double _restScale = 0.6;
const double _pressScale = 0.72;

/// A range of values, from [start] to [end].
@immutable
class GlassRange {
  const GlassRange(this.start, this.end);

  final double start;
  final double end;

  GlassRange copyWith({double? start, double? end}) => GlassRange(start ?? this.start, end ?? this.end);

  @override
  bool operator ==(Object other) => other is GlassRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'GlassRange($start, $end)';
}

/// A slider with two knobs, picking a range: white knobs on GlassSlider's
/// rail, the accent filling between them. The knobs can meet but not cross.
class GlassRangeSlider extends StatefulWidget {
  const GlassRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.semanticLabel,
    this.semanticFormatter,
    this.focusNode,
    this.endFocusNode,
    this.autofocus = false,
  })  : assert(divisions == null || divisions > 0),
        assert(min <= max);

  /// The range shown; its start must not be after its end.
  final GlassRange values;

  /// Called as either knob moves. Null disables the slider.
  final ValueChanged<GlassRange>? onChanged;
  final double min;
  final double max;

  /// Snaps the values to this many equal steps, if set.
  final int? divisions;
  final ValueChanged<GlassRange>? onChangeStart;
  final ValueChanged<GlassRange>? onChangeEnd;

  /// The fill's colour. Defaults to the theme's accent.
  final Color? activeColor;

  /// Names the slider for assistive technology.
  final String? semanticLabel;

  /// Describes a value for assistive technology. Defaults to a percentage.
  final String Function(double value)? semanticFormatter;

  /// The start knob's focus node.
  final FocusNode? focusNode;

  /// The end knob's focus node.
  final FocusNode? endFocusNode;

  /// Focuses the start knob when first built.
  final bool autofocus;

  @override
  State<GlassRangeSlider> createState() => _GlassRangeSliderState();
}

class _GlassRangeSliderState extends State<GlassRangeSlider> with TickerProviderStateMixin {
  late final List<GlassSpring> _press = [
    GlassSpring(vsync: this, stiffness: 700, damping: 34),
    GlassSpring(vsync: this, stiffness: 700, damping: 34),
  ];
  late final Listenable _motion = Listenable.merge(_press);

  FocusNode? _ownStartFocus;
  FocusNode? _ownEndFocus;

  // The knob under the pointer: 0 for start, 1 for end.
  int? _active;
  // The knob drawn on top: the one last moved.
  int _top = 1;
  bool _dragging = false;
  int? _focused;
  double _width = 0;
  bool _rtl = false;

  bool get _enabled => widget.onChanged != null && widget.max > widget.min;

  FocusNode get _startFocus => widget.focusNode ?? (_ownStartFocus ??= FocusNode(debugLabel: 'GlassRangeSlider start'));
  FocusNode get _endFocus => widget.endFocusNode ?? (_ownEndFocus ??= FocusNode(debugLabel: 'GlassRangeSlider end'));

  double _progressOf(double value) {
    if (widget.max <= widget.min) return 0;
    return ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  }

  double get _startProgress => _progressOf(widget.values.start);
  double get _endProgress => math.max(_startProgress, _progressOf(widget.values.end));

  double get _travel => math.max(1.0, _width - 2 * _inset);

  /// Where a knob at [progress] sits, in local px.
  double _xOf(double progress) => _inset + _travel * (_rtl ? 1 - progress : progress);

  /// The unsnapped progress under [x].
  double _progressAt(double x) {
    final raw = ((x - _inset) / _travel).clamp(0.0, 1.0);
    return _rtl ? 1 - raw : raw;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final spring in _press) {
      spring.reduceMotion = reduce;
    }
  }

  @override
  void didUpdateWidget(GlassRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownStartFocus?.dispose();
      _ownStartFocus = null;
    }
    if (oldWidget.endFocusNode != widget.endFocusNode && widget.endFocusNode != null) {
      _ownEndFocus?.dispose();
      _ownEndFocus = null;
    }
    if (!_enabled) {
      _active = null;
      _dragging = false;
      for (final spring in _press) {
        spring.set(0);
      }
    }
  }

  @override
  void dispose() {
    for (final spring in _press) {
      spring.dispose();
    }
    _ownStartFocus?.dispose();
    _ownEndFocus?.dispose();
    super.dispose();
  }

  double _snap(double progress) {
    progress = progress.clamp(0.0, 1.0);
    final divisions = widget.divisions;
    if (divisions != null) progress = (progress * divisions).round() / divisions;
    return widget.min + progress * (widget.max - widget.min);
  }

  /// [values] with [knob] moved to [value], kept from crossing the other.
  GlassRange _with(int knob, double value) {
    final values = widget.values;
    return knob == 0
        ? GlassRange(math.min(value, values.end), values.end)
        : GlassRange(values.start, math.max(value, values.start));
  }

  void _emit(GlassRange next) {
    if (next != widget.values) widget.onChanged?.call(next);
  }

  void _grab(int knob) {
    _active = knob;
    if (_top != knob) setState(() => _top = knob);
    _press[knob].set(1);
    _press[1 - knob].set(0);
  }

  /// Picks the knob nearer [x]; with the two together, the side [x] is on,
  /// or null when [x] is on both, for the first move to decide.
  int? _pick(double x) {
    final start = _xOf(_startProgress);
    final end = _xOf(_endProgress);
    final toStart = (x - start).abs();
    final toEnd = (x - end).abs();
    if ((start - end).abs() < 0.5) {
      final progress = _progressAt(x);
      if (progress < _startProgress - 1e-9) return 0;
      if (progress > _endProgress + 1e-9) return 1;
      return null;
    }
    return toStart <= toEnd ? 0 : 1;
  }

  void _down(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton) return;
    final knob = _pick(event.localPosition.dx);
    // Held on two knobs at once, both swell until a move picks one.
    if (knob == null) {
      _active = null;
      _press[0].set(1);
      _press[1].set(1);
    } else {
      _grab(knob);
    }
  }

  // Runs before a tap's callback, so leaves the knob picked for it.
  void _up(PointerEvent event) {
    if (_dragging) return;
    _press[0].set(0);
    _press[1].set(0);
  }

  /// The knob to move to [x], settling a tie by which way [x] lies.
  int? _knobFor(double x) {
    if (_active != null) return _active;
    final progress = _progressAt(x);
    // At either end only one knob can move.
    if (_startProgress <= 0 && _endProgress <= 0) {
      _grab(1);
    } else if (_startProgress >= 1 && _endProgress >= 1) {
      _grab(0);
    } else if (progress < _startProgress - 1e-9) {
      _grab(0);
    } else if (progress > _endProgress + 1e-9) {
      _grab(1);
    } else {
      return null;
    }
    return _active;
  }

  void _tapUp(TapUpDetails details) {
    if (!_enabled) return;
    final x = details.localPosition.dx;
    final knob = _active ?? _knobFor(x);
    if (knob != null) {
      final next = _with(knob, _snap(_progressAt(x)));
      widget.onChangeStart?.call(widget.values);
      _emit(next);
      widget.onChangeEnd?.call(next);
    }
    _active = null;
    _press[0].set(0);
    _press[1].set(0);
  }

  void _dragStart(DragStartDetails details) {
    if (!_enabled) return;
    _dragging = true;
    widget.onChangeStart?.call(widget.values);
    _move(details.localPosition.dx);
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _move(details.localPosition.dx);
  }

  void _move(double x) {
    final knob = _knobFor(x);
    if (knob == null) return;
    _emit(_with(knob, _snap(_progressAt(x))));
  }

  void _dragEnd([DragEndDetails? details]) {
    if (!_dragging) return;
    _dragging = false;
    _active = null;
    _press[0].set(0);
    _press[1].set(0);
    widget.onChangeEnd?.call(widget.values);
  }

  double get _step => widget.divisions != null ? 1 / widget.divisions! : 1 / 20;

  double _progressOfKnob(int knob) => knob == 0 ? _startProgress : _endProgress;

  void _nudge(int knob, double steps) {
    if (!_enabled) return;
    final next = _with(knob, _snap(_progressOfKnob(knob) + steps * _step));
    if (_top != knob) setState(() => _top = knob);
    widget.onChangeStart?.call(widget.values);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  void _jump(int knob, double progress) {
    if (!_enabled) return;
    final next = _with(knob, _snap(progress));
    widget.onChangeStart?.call(widget.values);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  String _describe(double progress) {
    progress = progress.clamp(0.0, 1.0);
    final format = widget.semanticFormatter;
    if (format != null) return format(widget.min + progress * (widget.max - widget.min));
    return '${(progress * 100).round()}%';
  }

  /// What a knob would show one step further, kept from crossing the other.
  double _steppedProgress(int knob, double steps) {
    final next = (_progressOfKnob(knob) + steps * _step).clamp(0.0, 1.0);
    return knob == 0 ? math.min(next, _endProgress) : math.max(next, _startProgress);
  }

  Widget _knob(int knob) {
    final progress = _progressOfKnob(knob);
    final x = _xOf(progress);
    final canIncrease = _enabled && _steppedProgress(knob, 1) > progress + 1e-9;
    final canDecrease = _enabled && _steppedProgress(knob, -1) < progress - 1e-9;
    // Right moves right, whichever way the page reads.
    final forward = _rtl ? -1.0 : 1.0;
    return Positioned(
      // Keyed, so each knob keeps its focus as the draw order changes.
      key: ValueKey<int>(knob),
      left: x - _thumbWidth * _restScale / 2,
      top: 0,
      width: _thumbWidth * _restScale,
      height: _height,
      child: Semantics(
        container: true,
        slider: true,
        enabled: _enabled,
        label: knob == 0 ? 'Start' : 'End',
        value: _describe(progress),
        increasedValue: _describe(_steppedProgress(knob, 1)),
        decreasedValue: _describe(_steppedProgress(knob, -1)),
        onIncrease: canIncrease ? () => _nudge(knob, 1) : null,
        onDecrease: canDecrease ? () => _nudge(knob, -1) : null,
        child: FocusableActionDetector(
          focusNode: knob == 0 ? _startFocus : _endFocus,
          autofocus: knob == 0 && widget.autofocus,
          enabled: _enabled,
          mouseCursor: MouseCursor.defer,
          onShowFocusHighlight: (value) {
            setState(() {
              if (value) {
                _focused = knob;
                _top = knob;
              } else if (_focused == knob) {
                _focused = null;
              }
            });
          },
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(forward),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-forward),
            const SingleActivator(LogicalKeyboardKey.arrowUp): const _NudgeIntent(1),
            const SingleActivator(LogicalKeyboardKey.arrowDown): const _NudgeIntent(-1),
            const SingleActivator(LogicalKeyboardKey.pageUp): const _NudgeIntent(5),
            const SingleActivator(LogicalKeyboardKey.pageDown): const _NudgeIntent(-5),
            const SingleActivator(LogicalKeyboardKey.home): const _JumpIntent(0),
            const SingleActivator(LogicalKeyboardKey.end): const _JumpIntent(1),
          },
          actions: <Type, Action<Intent>>{
            _NudgeIntent: CallbackAction<_NudgeIntent>(onInvoke: (intent) {
              _nudge(knob, intent.steps);
              return null;
            }),
            _JumpIntent: CallbackAction<_JumpIntent>(onInvoke: (intent) {
              _jump(knob, intent.progress);
              return null;
            }),
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    _rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    Widget result = LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 200.0;
      _width = width;
      final start = _xOf(_startProgress);
      final end = _xOf(_endProgress);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(width, _height),
            painter: _RangePainter(
              theme: theme,
              start: start,
              end: end,
              top: _top,
              focused: _focused,
              press: _press,
              activeColor: widget.activeColor ?? theme.fill,
              repaint: _motion,
            ),
          ),
          // Draw order follows the knobs, so the top one is read last.
          for (final knob in _top == 0 ? const [1, 0] : const [0, 1]) _knob(knob),
        ],
      );
    });
    result = SizedBox(height: _height, child: result);
    result = Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Each knob describes itself, with increase and decrease.
        excludeFromSemantics: true,
        onTapUp: _enabled ? _tapUp : null,
        onHorizontalDragStart: _enabled ? _dragStart : null,
        onHorizontalDragUpdate: _enabled ? _dragUpdate : null,
        onHorizontalDragEnd: _enabled ? _dragEnd : null,
        onHorizontalDragCancel: _enabled ? _dragEnd : null,
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: result,
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Opacity(opacity: _enabled ? 1 : 0.35, child: result),
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

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.theme,
    required this.start,
    required this.end,
    required this.top,
    required this.focused,
    required this.press,
    required this.activeColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GlassThemeData theme;
  final double start;
  final double end;
  final int top;
  final int? focused;
  final List<GlassSpring> press;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rail = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, _trackTop, size.width, _trackHeight),
      const Radius.circular(_trackHeight / 2),
    );
    canvas.drawRRect(rail, Paint()..color = theme.rail);
    final left = math.min(start, end);
    final right = math.max(start, end);
    // The fill runs between the knobs' middles, rounded at both ends.
    final fill = Rect.fromLTRB(left - _trackHeight / 2, _trackTop, right + _trackHeight / 2, _trackTop + _trackHeight);
    canvas.drawRRect(
        RRect.fromRectAndRadius(fill, const Radius.circular(_trackHeight / 2)), Paint()..color = activeColor);

    for (final knob in top == 0 ? const [1, 0] : const [0, 1]) {
      final x = knob == 0 ? start : end;
      final rect = Rect.fromCenter(center: Offset(x, _height / 2), width: _thumbWidth, height: _thumbHeight);
      final scale = _restScale + (_pressScale - _restScale) * press[knob].value;
      paintThumbChrome(canvas, rect: rect, scale: scale, lift: 0);
      if (focused == knob) {
        canvas.drawRRect(
          roundedRect(scaleAbout(rect, scale), double.infinity).inflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = theme.ring,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RangePainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.top != top ||
      oldDelegate.focused != focused ||
      oldDelegate.activeColor != activeColor;
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'button.dart';
import 'control_utils.dart';
import 'input.dart' show GlassGlyph;
import 'hairline.dart';

/// An iOS stepper on glass: a capsule split into − and +, each lighting up
/// under a finger. Held, a half repeats, faster the longer it's held.
class GlassStepper extends StatefulWidget {
  const GlassStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  })  : assert(max >= min),
        assert(step > 0);

  final double value;

  /// Null disables the stepper.
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final double step;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassStepper> createState() => _GlassStepperState();
}

class _GlassStepperState extends State<GlassStepper> {
  static const double _width = 94;
  static const double _height = 32;

  int _pressed = 0; // -1 for −, 1 for +.
  Timer? _repeat;
  int _repeats = 0;
  late double _latest = widget.value;

  bool get _enabled => widget.onChanged != null;
  bool _can(int direction) => _enabled && (direction < 0 ? _latest > widget.min + 1e-9 : _latest < widget.max - 1e-9);

  @override
  void didUpdateWidget(GlassStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _latest = widget.value;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _stepBy(int direction) {
    if (!_can(direction)) {
      _stop();
      return;
    }
    final next = (_latest + direction * widget.step).clamp(widget.min, widget.max).toDouble();
    // Keep to the grid of steps from min, against floating-point drift.
    final snapped = widget.min + ((next - widget.min) / widget.step).round() * widget.step;
    _latest = snapped.clamp(widget.min, widget.max).toDouble();
    widget.onChanged!(_latest);
  }

  void _down(int direction) {
    if (!_can(direction)) return;
    setState(() => _pressed = direction);
  }

  void _startRepeat(int direction) {
    _repeat?.cancel();
    _repeats = 0;
    setState(() => _pressed = direction);
    void tick() {
      _stepBy(direction);
      _repeats++;
      // Speeds up the longer it's held, as UIStepper does.
      final interval = _repeats < 6 ? 140 : (_repeats < 20 ? 80 : 40);
      _repeat = Timer(Duration(milliseconds: interval), tick);
    }

    tick();
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    if (mounted && _pressed != 0) setState(() => _pressed = 0);
  }

  Widget _half(GlassThemeData theme, int direction) {
    final can = _can(direction);
    final glyph = direction < 0
        ? GlassGlyph.minus(color: theme.foreground, size: 16)
        : GlassGlyph.plus(color: theme.foreground, size: 16);
    return Expanded(
      child: Semantics(
        button: true,
        enabled: can,
        label: direction < 0 ? 'Decrement' : 'Increment',
        onTap: can ? () => _stepBy(direction) : null,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(direction),
          onTapUp: (_) {
            _stop();
            _stepBy(direction);
          },
          onTapCancel: _stop,
          onLongPressStart: can ? (_) => _startRepeat(direction) : null,
          onLongPressEnd: (_) => _stop(),
          onLongPressCancel: _stop,
          child: GlassPressableGlow(
            radius: _height / 2,
            enabled: can,
            child: AnimatedContainer(
              duration: _pressed == direction ? Duration.zero : const Duration(milliseconds: 200),
              color: _pressed == direction ? theme.highlight : const Color(0x00000000),
              child: Center(child: Opacity(opacity: can ? 1 : 0.3, child: glyph)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final stepper = LiquidGlassBox(
      radius: _height / 2,
      style: themedGlass(theme),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_height / 2),
        child: SizedBox(
          width: _width,
          height: _height,
          child: Row(
            children: [
              _half(theme, -1),
              Container(width: hairline(context), height: _height * 0.55, color: theme.separator),
              _half(theme, 1),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      value: _format(widget.value),
      increasedValue: _format(math.min(widget.max, widget.value + widget.step)),
      decreasedValue: _format(math.max(widget.min, widget.value - widget.step)),
      onIncrease: _can(1) ? () => _stepBy(1) : null,
      onDecrease: _can(-1) ? () => _stepBy(-1) : null,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _StepIntent: CallbackAction<_StepIntent>(onInvoke: (intent) {
              _stepBy(intent.direction);
              return null;
            }),
          },
          child: GlassFocusable(
            enabled: _enabled,
            onActivate: () => _stepBy(1),
            radius: _height / 2,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            child: Opacity(opacity: _enabled ? 1 : 0.35, child: stepper),
          ),
        ),
      ),
    );
  }

  String _format(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _StepIntent extends Intent {
  const _StepIntent(this.direction);

  final int direction;
}

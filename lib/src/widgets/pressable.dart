import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';

/// How glass answers a press: how much its longer side grows, and its
/// springs' stiffness and damping pressing and letting go.
class _Feel {
  const _Feel(this.grow, this.press, this.release);

  final double grow;
  final (double, double) press;
  final (double, double) release;
}

// A mouse press stays subtle.
const _Feel _pointer = _Feel(6, (417.6, 29.2), (230, 23.7));
// A finger gets the iOS 26 glass button: it grows until its longer side is
// about 15pt bigger, and bounces back past its resting size on release.
const _Feel _touch = _Feel(15, (515, 27.3), (250, 11.8));

/// Where a press is and whether one is under way, for a pressable's glow.
class PressState {
  const PressState({required this.pressed, required this.position});

  final bool pressed;

  /// Where the pointer is, as a share of the box (0 to 1 each way).
  final Offset position;

  static const PressState idle = PressState(pressed: false, position: Offset(0.5, 0.5));
}

/// Makes its child press like iOS 26 glass: it swells under a finger,
/// stretches towards a drag with a rubbery give, and springs back past its
/// size when let go.
class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.onPressChanged,
    this.builder,
  });

  final Widget child;
  final bool enabled;
  final ValueChanged<PressState>? onPressChanged;

  /// Builds over the child with the press's state, as for a glow.
  final Widget Function(BuildContext context, PressState state, Widget child)? builder;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable> with TickerProviderStateMixin {
  late final List<GlassSpring> _springs = [1.0, 1.0, 0.0, 0.0]
      .map((v) => GlassSpring(vsync: this, value: v, stiffness: _pointer.release.$1, damping: _pointer.release.$2))
      .toList();
  late final Listenable _motion = Listenable.merge(_springs);

  int? _pointerId;
  Offset _start = Offset.zero;
  _Feel _feel = _pointer;
  PressState _state = PressState.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final spring in _springs) {
      spring.reduceMotion = reduce;
    }
  }

  @override
  void didUpdateWidget(GlassPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pointerId != null) _end(null);
  }

  @override
  void dispose() {
    for (final spring in _springs) {
      spring.dispose();
    }
    super.dispose();
  }

  void _target(List<double> next, (double, double) feel) {
    for (var i = 0; i < 4; i++) {
      _springs[i]
        ..tune(feel.$1, feel.$2)
        ..set(next[i]);
    }
  }

  void _setState(PressState state) {
    if (state.pressed == _state.pressed && state.position == _state.position) return;
    _state = state;
    widget.onPressChanged?.call(state);
    if (widget.builder != null) setState(() {});
  }

  void _track(Offset local) {
    final box = context.size;
    if (box == null || box.isEmpty) return;
    _setState(PressState(
      pressed: true,
      position: Offset((local.dx / box.width).clamp(-1.0, 2.0), (local.dy / box.height).clamp(-1.0, 2.0)),
    ));
    final width = box.width;
    final height = box.height;
    final base = 1 + _feel.grow / math.max(width, height);
    final aspect = width / height;
    final dx = (local.dx - _start.dx) / aspect;
    final dy = local.dy - _start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) {
      _target([base, base, 0, 0], _feel.press);
      return;
    }
    final nx = dx / length;
    final ny = dy / length;
    final rubber = 1 - 1 / (1 + length / height / (5 * aspect));
    final stretch = 1 + (6 / height) * rubber * (nx.abs() - ny.abs()).abs();
    final horizontal = nx.abs() > ny.abs();
    _target([
      base * (horizontal ? stretch : 1 / stretch),
      base * (horizontal ? 1 / stretch : stretch),
      nx * 8 * rubber,
      ny * 8 * rubber,
    ], _feel.press);
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointerId != null) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    _pointerId = event.pointer;
    _start = event.localPosition;
    _feel = event.kind == PointerDeviceKind.mouse ? _pointer : _touch;
    _track(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointerId) return;
    _track(event.localPosition);
  }

  void _end(PointerEvent? event) {
    if (event != null && event.pointer != _pointerId) return;
    _pointerId = null;
    _setState(PressState(pressed: false, position: _state.position));
    _target([1, 1, 0, 0], _feel.release);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder == null ? widget.child : widget.builder!(context, _state, widget.child);
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: AnimatedBuilder(
        animation: _motion,
        child: child,
        builder: (context, child) {
          final sx = _springs[0].value;
          final sy = _springs[1].value;
          final tx = _springs[2].value;
          final ty = _springs[3].value;
          // Always a Transform, so the child keeps its place in the tree.
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(tx, ty, 0)..multiply(Matrix4.diagonal3Values(sx, sy, 1)),
            child: child,
          );
        },
      ),
    );
  }
}

/// The soft light under a finger on pressed glass, as Glisse's `::after`.
class PressGlow extends StatelessWidget {
  const PressGlow({super.key, required this.state, required this.radius, this.strength = 1});

  final PressState state;
  final double radius;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: state.pressed ? strength : 0,
        duration: state.pressed ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: CustomPaint(painter: _GlowPainter(state.position, radius), size: Size.infinite),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.at, this.radius);

  final Offset at;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(at.dx * size.width, at.dy * size.height);
    final shader = const RadialGradient(
      colors: [Color.fromRGBO(255, 255, 255, 0.035), Color.fromRGBO(255, 255, 255, 0.025), Color(0x00FFFFFF)],
      stops: [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: center, radius: 240));
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(math.min(radius, size.shortestSide / 2)));
    canvas.drawRRect(rrect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.at != at || oldDelegate.radius != radius;
}

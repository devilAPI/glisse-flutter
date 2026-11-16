import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';
import 'input.dart' show GlassGlyph;
import 'pressable.dart';

// The gap between the knob and the track's edge.
const double _inset = 4;

/// A glass capsule with a round knob to slide across, for actions worth a
/// second thought, as "slide to power off".
///
/// Let go past [threshold] of the way and the knob snaps to the end, shows a
/// tick and calls [onConfirmed]; let go short of it and it springs back.
class GlassSlideToConfirm extends StatefulWidget {
  /// Creates a slide to confirm; [threshold] must be above 0 and at most 1, and [height] at least 32.
  const GlassSlideToConfirm({
    super.key,
    required this.onConfirmed,
    this.label = 'Slide to confirm',
    this.confirmedLabel,
    this.resetAfter,
    this.threshold = 0.9,
    this.height = 56,
    this.activeColor,
    this.shimmer = true,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(threshold > 0 && threshold <= 1),
       assert(height >= 32);

  /// Called once the slide is confirmed. Null disables the control.
  final VoidCallback? onConfirmed;

  /// The words on the track.
  final String label;

  /// Shown on the filled track once confirmed, if set.
  final String? confirmedLabel;

  /// If set, how long after confirming the knob springs back to the start.
  final Duration? resetAfter;

  /// How far along, from 0 to 1, the knob must be let go to confirm.
  final double threshold;

  /// The track's height.
  final double height;

  /// The fill behind the knob. Defaults to the theme's accent.
  final Color? activeColor;

  /// Whether the label shimmers. It never does under reduced motion.
  final bool shimmer;

  /// Defaults to [label].
  final String? semanticLabel;

  /// The control's focus node, to drive or watch its focus.
  final FocusNode? focusNode;

  /// Whether it takes focus when first built.
  final bool autofocus;

  @override
  State<GlassSlideToConfirm> createState() => _GlassSlideToConfirmState();
}

class _GlassSlideToConfirmState extends State<GlassSlideToConfirm> with TickerProviderStateMixin {
  // How far along the knob is, from 0 to 1.
  late final GlassSpring _position = GlassSpring(vsync: this, stiffness: 420, damping: 34);
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _reduceMotion = false;
  bool _dragging = false;
  bool _confirmed = false;
  double _travel = 1;
  Timer? _reset;

  bool get _enabled => widget.onConfirmed != null;
  bool get _interactive => _enabled && !_confirmed;
  bool get _shimmering => widget.shimmer && !_reduceMotion && _interactive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _position.reduceMotion = _reduceMotion;
    _syncShine();
  }

  @override
  void didUpdateWidget(GlassSlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _dragging) {
      _dragging = false;
      _position.set(0);
    }
    _syncShine();
  }

  @override
  void dispose() {
    _reset?.cancel();
    _position.dispose();
    _shine.dispose();
    super.dispose();
  }

  void _syncShine() {
    if (_shimmering) {
      if (!_shine.isAnimating) _shine.repeat();
    } else if (_shine.isAnimating) {
      _shine.stop();
    }
  }

  double get _direction => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _dragStart(DragStartDetails details) {
    if (!_interactive) return;
    _dragging = true;
    _position.stop();
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final next = (_position.value + _direction * details.delta.dx / _travel).clamp(0.0, 1.0);
    _position.set(next, instant: true);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    if (_position.value >= widget.threshold) {
      _confirm();
      return;
    }
    // A fling back keeps its speed; one forward that fell short doesn't.
    final velocity = _direction * details.velocity.pixelsPerSecond.dx / _travel;
    _position.jump(_position.value, velocity: math.min(0.0, velocity));
    _position.set(0);
  }

  void _dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _position.set(0);
  }

  // A tap on the track nudges the knob, hinting that it slides.
  void _hint() {
    if (!_interactive || _dragging || _position.isMoving || _position.value != 0) return;
    _position.jump(0, velocity: 4);
  }

  void _confirm() {
    if (!_interactive) return;
    _dragging = false;
    setState(() => _confirmed = true);
    _position.set(1);
    _syncShine();
    unawaited(HapticFeedback.mediumImpact());
    widget.onConfirmed!();
    final after = widget.resetAfter;
    if (after != null) {
      _reset?.cancel();
      _reset = Timer(after, () {
        if (!mounted) return;
        setState(() => _confirmed = false);
        _position.set(0);
        _syncShine();
      });
    }
  }

  Widget _label(GlassThemeData theme) {
    final style = theme.textStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2);
    final text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: _shimmering ? const Color(0xFFFFFFFF) : theme.muted),
    );
    if (!_shimmering) return text;
    final rtl = _direction < 0;
    return AnimatedBuilder(
      animation: _shine,
      child: text,
      builder: (context, child) {
        // A band of brighter ink sweeps across, the way the slide goes.
        final at = -2.0 + 4 * Curves.easeInOut.transform(_shine.value);
        final c = rtl ? -at : at;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback:
              (bounds) => LinearGradient(
                begin: Alignment(c - 1, 0),
                end: Alignment(c + 1, 0),
                colors: [theme.muted, theme.foreground, theme.muted],
                stops: const [0.3, 0.5, 0.7],
              ).createShader(bounds),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final accent = widget.activeColor ?? theme.fill;
    final height = widget.height;
    final knobSize = height - 2 * _inset;
    final rtl = _direction < 0;

    Widget knob = LiquidGlassBox(
      radius: double.infinity,
      style: themedGlass(
        theme,
        // White in both themes, as iOS's slide to power off.
        tint: const Color.fromRGBO(255, 255, 255, 0.94),
      ),
      child: SizedBox.square(
        dimension: knobSize,
        child: Center(
          child:
              _confirmed
                  ? GlassGlyph.check(color: accent, size: knobSize * 0.46)
                  : SizedBox.square(
                    dimension: knobSize * 0.42,
                    child: CustomPaint(painter: _ArrowPainter(color: accent, flip: rtl)),
                  ),
        ),
      ),
    );
    knob = GlassPressable(enabled: _interactive, child: knob);
    knob = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _interactive ? _dragStart : null,
      onHorizontalDragUpdate: _interactive ? _dragUpdate : null,
      onHorizontalDragEnd: _interactive ? _dragEnd : null,
      onHorizontalDragCancel: _interactive ? _dragCancel : null,
      child: knob,
    );

    final label = _label(theme);
    final done =
        widget.confirmedLabel == null
            ? null
            : Text(
              widget.confirmedLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textStyle.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            );

    Widget track = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 300.0;
        _travel = math.max(1.0, width - 2 * _inset - knobSize);
        return SizedBox(
          width: width,
          height: height,
          child: AnimatedBuilder(
            animation: _position,
            child: knob,
            builder: (context, knob) {
              final t = _position.value;
              final p = t.clamp(0.0, 1.0);
              final start = _inset + t * _travel;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // The label, which the fill covers as it comes.
                  PositionedDirectional(
                    start: _inset + knobSize + 8,
                    end: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(child: Opacity(opacity: (1 - p / 0.35).clamp(0.0, 1.0), child: label)),
                  ),
                  // The accent, revealed behind the knob as it goes.
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: math.min(width, math.max(height, start + knobSize + _inset)),
                    child: Opacity(
                      opacity: (p * 5).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(height / 2)),
                      ),
                    ),
                  ),
                  if (done != null)
                    PositionedDirectional(
                      start: 16,
                      end: _inset + knobSize + 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Opacity(opacity: _confirmed ? ((p - 0.6) / 0.4).clamp(0.0, 1.0) : 0, child: done),
                      ),
                    ),
                  PositionedDirectional(start: start, top: _inset, width: knobSize, height: knobSize, child: knob!),
                ],
              );
            },
          ),
        );
      },
    );

    track = LiquidGlassBox(radius: double.infinity, style: themedGlass(theme), child: track);
    track = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: _interactive ? _hint : null,
      child: track,
    );

    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel ?? widget.label,
      value: _confirmed ? (widget.confirmedLabel ?? 'Confirmed') : null,
      onTap: _interactive ? _confirm : null,
      child: GlassFocusable(
        enabled: _interactive,
        onActivate: _confirm,
        radius: height / 2,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        child: Opacity(opacity: _enabled ? 1 : 0.35, child: ExcludeSemantics(child: track)),
      ),
    );
  }
}

/// An arrow pointing the way the knob slides.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.flip});

  final Color color;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    if (flip) {
      canvas.translate(16, 0);
      canvas.scale(-1, 1);
    }
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(2.5, 8), const Offset(13, 8), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(8.5, 3.5)
        ..lineTo(13, 8)
        ..lineTo(8.5, 12.5),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color || oldDelegate.flip != flip;
}

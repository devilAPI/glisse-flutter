import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/hit_padding.dart';

/// The stars' default fill: a warm amber, as rating stars are on iOS.
const Color glassRatingAmber = Color(0xFFFFB800);

/// A star rating: a row of stars that fill with amber as far as [value].
/// Tap a star, or drag across them, to set it; the star touched pops.
///
/// With [onChanged] null the rating only shows [value], which may be any
/// fraction, such as an average of 4.3.
class GlassRating extends StatefulWidget {
  /// Creates a star rating; [count] and [size] must be positive and [spacing] not negative.
  const GlassRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.count = 5,
    this.allowHalf = false,
    this.size = 28,
    this.spacing = 4,
    this.color,
    this.emptyColor,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(count > 0),
       assert(size > 0),
       assert(spacing >= 0);

  /// How many stars are filled, from 0 to [count].
  final double value;

  /// Called with the new rating. Null makes the rating read-only.
  final ValueChanged<double>? onChanged;

  /// How many stars there are.
  final int count;

  /// Whether a rating can end in half a star.
  final bool allowHalf;

  /// Each star's width and height.
  final double size;

  /// The gap between stars.
  final double spacing;

  /// The filled stars' colour. Defaults to [glassRatingAmber].
  final Color? color;

  /// The empty stars' colour. Defaults to the theme's track.
  final Color? emptyColor;

  /// Names the control for assistive technology.
  final String? semanticLabel;

  /// The control's focus node, to drive or watch its focus.
  final FocusNode? focusNode;

  /// Whether it takes focus when first built.
  final bool autofocus;

  @override
  State<GlassRating> createState() => _GlassRatingState();
}

class _GlassRatingState extends State<GlassRating> with TickerProviderStateMixin {
  // Each star's scale; underdamped, so a touched star pops past its size.
  late List<GlassSpring> _pops = _springs(widget.count);
  late Listenable _motion = Listenable.merge(_pops);
  bool _focused = false;
  bool _reduceMotion = false;
  bool _dragging = false;

  bool get _enabled => widget.onChanged != null;
  bool get _rtl => Directionality.maybeOf(context) == TextDirection.rtl;
  double get _step => widget.allowHalf ? 0.5 : 1;
  double get _width => widget.count * widget.size + (widget.count - 1) * widget.spacing;

  List<GlassSpring> _springs(int count) => [
    for (var i = 0; i < count; i++)
      GlassSpring(vsync: this, value: 1, stiffness: 520, damping: 13)..reduceMotion = _reduceMotion,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final spring in _pops) {
      spring.reduceMotion = _reduceMotion;
    }
  }

  @override
  void didUpdateWidget(GlassRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      for (final spring in _pops) {
        spring.dispose();
      }
      _pops = _springs(widget.count);
      _motion = Listenable.merge(_pops);
    }
    if (!_enabled) _dragging = false;
  }

  @override
  void dispose() {
    for (final spring in _pops) {
      spring.dispose();
    }
    super.dispose();
  }

  /// The rating a touch at [x] gives.
  double _valueAt(double x) {
    if (_rtl) x = _width - x;
    if (x < 0) return 0;
    final slot = widget.size + widget.spacing;
    final index = (x / slot).floor().clamp(0, widget.count - 1);
    final within = ((x - index * slot) / widget.size).clamp(0.0, 1.0);
    if (widget.allowHalf && within < 0.5) return index + 0.5;
    return index + 1.0;
  }

  void _pop(double value) {
    if (value <= 0 || _reduceMotion) return;
    final index = (value.ceil() - 1).clamp(0, widget.count - 1);
    _pops[index].jump(1, velocity: 5);
  }

  void _set(double value) {
    if (!_enabled) return;
    value = value.clamp(0.0, widget.count.toDouble());
    if (value == widget.value) return;
    _pop(value);
    widget.onChanged!(value);
  }

  void _nudge(double steps) => _set(_stepped(widget.value, steps > 0 ? 1 : -1));

  /// The next point on the step grid above or below [value]: from 3.7, up is
  /// 4 and down is 3.
  double _stepped(double value, int direction) {
    final next =
        direction > 0
            ? ((value + 1e-9) / _step).floor() * _step + _step
            : ((value - 1e-9) / _step).ceil() * _step - _step;
    return next.clamp(0.0, widget.count.toDouble());
  }

  String _describe(double value) {
    final shown = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    return '$shown of ${widget.count} ${widget.count == 1 ? 'star' : 'stars'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final rtl = _rtl;
    final value = widget.value.clamp(0.0, widget.count.toDouble());
    Widget stars = CustomPaint(
      size: Size(_width, widget.size),
      painter: _StarsPainter(
        value: value,
        count: widget.count,
        size: widget.size,
        spacing: widget.spacing,
        rtl: rtl,
        fill: widget.color ?? glassRatingAmber,
        empty: widget.emptyColor ?? theme.track,
        pops: _pops,
        repaint: _motion,
      ),
    );
    // Always a Stack, so the stars keep their place as the ring comes and goes.
    stars = Stack(
      clipBehavior: Clip.none,
      children: [
        stars,
        if (_focused)
          Positioned(
            left: -6,
            top: -6,
            right: -6,
            bottom: -6,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.ring, width: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (_enabled) {
      stars = GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _set(_valueAt(details.localPosition.dx)),
        onHorizontalDragStart: (details) {
          _dragging = true;
          _set(_valueAt(details.localPosition.dx));
        },
        onHorizontalDragUpdate: (details) {
          if (_dragging) _set(_valueAt(details.localPosition.dx));
        },
        onHorizontalDragEnd: (_) => _dragging = false,
        onHorizontalDragCancel: () => _dragging = false,
        child: stars,
      );
      // Small stars still take a finger-sized touch.
      final reach = math.max(0.0, (44 - widget.size) / 2);
      stars = HitPadding(padding: EdgeInsets.symmetric(vertical: reach), child: stars);
    }
    final forward = rtl ? -1.0 : 1.0;
    stars = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): _RateIntent(forward),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _RateIntent(-forward),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _RateIntent(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _RateIntent(-1),
        const SingleActivator(LogicalKeyboardKey.home): const _RateIntent(double.negativeInfinity),
        const SingleActivator(LogicalKeyboardKey.end): const _RateIntent(double.infinity),
      },
      actions: <Type, Action<Intent>>{
        _RateIntent: CallbackAction<_RateIntent>(
          onInvoke: (intent) {
            if (intent.steps.isInfinite) {
              _set(intent.steps > 0 ? widget.count.toDouble() : 0);
            } else {
              _nudge(intent.steps);
            }
            return null;
          },
        ),
      },
      child: stars,
    );
    final canIncrease = _enabled && value < widget.count;
    final canDecrease = _enabled && value > 0;
    return Semantics(
      container: true,
      slider: _enabled,
      readOnly: !_enabled,
      label: widget.semanticLabel,
      value: _describe(value),
      increasedValue: canIncrease ? _describe(_stepped(value, 1)) : null,
      decreasedValue: canDecrease ? _describe(_stepped(value, -1)) : null,
      onIncrease: canIncrease ? () => _nudge(1) : null,
      onDecrease: canDecrease ? () => _nudge(-1) : null,
      child: stars,
    );
  }
}

class _RateIntent extends Intent {
  const _RateIntent(this.steps);

  final double steps;
}

/// A five-pointed star filling a [size] square, point up, its tips rounded
/// by [stroke] of the same colour.
Path _star(Offset center, double size, double stroke) {
  final outer = size / 2 - stroke / 2;
  final inner = outer * 0.5;
  // A point-up star reaches further above its middle than below.
  final shifted = center.translate(0, outer * (1 - math.cos(math.pi / 5)) / 2);
  final path = Path();
  for (var k = 0; k < 10; k++) {
    final angle = -math.pi / 2 + k * math.pi / 5;
    final r = k.isEven ? outer : inner;
    final point = shifted + Offset(math.cos(angle) * r, math.sin(angle) * r);
    k == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({
    required this.value,
    required this.count,
    required this.size,
    required this.spacing,
    required this.rtl,
    required this.fill,
    required this.empty,
    required this.pops,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final double value;
  final int count;
  final double size;
  final double spacing;
  final bool rtl;
  final Color fill;
  final Color empty;
  final List<GlassSpring> pops;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final stroke = size * 0.08;
    Paint paintOf(Color color) =>
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
    Paint edgeOf(Color color) =>
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < count; i++) {
      final left = rtl ? canvasSize.width - (i * (size + spacing) + size) : i * (size + spacing);
      final center = Offset(left + size / 2, size / 2);
      final scale = i < pops.length ? pops[i].value : 1.0;
      final star = _star(center, size, stroke);
      final shown = (value - i).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      canvas.translate(-center.dx, -center.dy);
      // A part star splits where the fill ends, from the side the row starts on.
      final split = rtl ? left + size * (1 - shown) : left + size * shown;
      final filled =
          rtl
              ? Rect.fromLTRB(split, -size, left + size + stroke, size * 2)
              : Rect.fromLTRB(left - stroke, -size, split, size * 2);
      final bare =
          rtl
              ? Rect.fromLTRB(left - stroke, -size, split, size * 2)
              : Rect.fromLTRB(split, -size, left + size + stroke, size * 2);
      for (final (part, color, clip) in [(shown < 1, empty, bare), (shown > 0, fill, filled)]) {
        if (!part) continue;
        canvas.save();
        if (shown > 0 && shown < 1) canvas.clipRect(clip);
        final opaque = color.withValues(alpha: 1);
        // A see-through colour goes on as one layer, so the rounding stroke
        // doesn't darken the star's rim where it overlaps the fill.
        final layered = color.a < 1;
        if (layered) {
          canvas.saveLayer(star.getBounds().inflate(stroke), Paint()..color = Color.fromRGBO(0, 0, 0, color.a));
        }
        canvas.drawPath(star, paintOf(opaque));
        canvas.drawPath(star, edgeOf(opaque));
        if (layered) canvas.restore();
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.count != count ||
      oldDelegate.size != size ||
      oldDelegate.spacing != spacing ||
      oldDelegate.rtl != rtl ||
      oldDelegate.fill != fill ||
      oldDelegate.empty != empty ||
      !identical(oldDelegate.pops, pops);
}

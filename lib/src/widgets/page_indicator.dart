import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

/// Page dots in a small glass capsule. The current page's dot is a pill that
/// flows between dots like a drop of liquid: it stretches towards the next
/// page as [page] passes halfway, then lets go of the last.
///
/// [page] may be fractional, as a `PageController`'s is mid-swipe: the pill
/// then follows it exactly. A whole-page jump springs.
class GlassPageIndicator extends StatefulWidget {
  const GlassPageIndicator({
    super.key,
    required this.count,
    required this.page,
    this.onTap,
    this.color,
    this.semanticLabel,
  }) : assert(count > 0);

  final int count;
  final double page;

  /// Called with the page whose dot was tapped.
  final ValueChanged<int>? onTap;

  /// The current dot's colour; defaults to the theme's foreground.
  final Color? color;
  final String? semanticLabel;

  @override
  State<GlassPageIndicator> createState() => _GlassPageIndicatorState();
}

class _GlassPageIndicatorState extends State<GlassPageIndicator> with SingleTickerProviderStateMixin {
  static const double _dot = 7;
  static const double _gap = 9;
  static const double _pitch = _dot + _gap;
  static const double _padX = 10;
  static const double _height = 23;

  late final GlassSpring _page = GlassSpring(vsync: this, value: widget.page, stiffness: 420, damping: 34);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _page.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassPageIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.page.clamp(0.0, (widget.count - 1).toDouble());
    // A page between pages follows a drag: keep up with it exactly.
    final following = next != next.roundToDouble() || (next - _page.value).abs() < 0.999;
    _page.set(next, instant: following && !_page.isMoving);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  int get _current => widget.page.round().clamp(0, widget.count - 1);

  void _go(int index) {
    if (widget.onTap != null && index >= 0 && index < widget.count) widget.onTap!(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final width = _padX * 2 + widget.count * _dot + (widget.count - 1) * _gap;
    Widget dots = LiquidGlassBox(
      radius: double.infinity,
      style: themedGlass(theme),
      child: SizedBox(
        width: width,
        height: _height,
        child: CustomPaint(
          painter: _DotsPainter(
            count: widget.count,
            page: _page,
            active: widget.color ?? theme.foreground,
            idle: theme.foreground.withValues(alpha: theme.foreground.a * 0.3),
          ),
        ),
      ),
    );
    if (widget.onTap != null) {
      dots = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _go(((details.localPosition.dx - _padX + _gap / 2) / _pitch).floor()),
        child: dots,
      );
    }
    return Semantics(
      label: widget.semanticLabel,
      value: 'Page ${_current + 1} of ${widget.count}',
      increasedValue: 'Page ${math.min(widget.count, _current + 2)} of ${widget.count}',
      decreasedValue: 'Page ${math.max(1, _current)} of ${widget.count}',
      onIncrease: widget.onTap != null && _current < widget.count - 1 ? () => _go(_current + 1) : null,
      onDecrease: widget.onTap != null && _current > 0 ? () => _go(_current - 1) : null,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _PageIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _PageIntent(-1),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PageIntent: CallbackAction<_PageIntent>(onInvoke: (intent) {
              _go(_current + intent.delta);
              return null;
            }),
          },
          child: GlassFocusable(
            enabled: widget.onTap != null,
            onActivate: () => _go((_current + 1) % widget.count),
            radius: _height / 2,
            child: dots,
          ),
        ),
      ),
    );
  }
}

class _PageIntent extends Intent {
  const _PageIntent(this.delta);

  final int delta;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.count, required this.page, required this.active, required this.idle})
      : super(repaint: page);

  final int count;
  final GlassSpring page;
  final Color active;
  final Color idle;

  static const double _dot = _GlassPageIndicatorState._dot;
  static const double _pitch = _GlassPageIndicatorState._pitch;
  static const double _padX = _GlassPageIndicatorState._padX;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dotPaint = Paint()..color = idle;
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(Offset(_padX + i * _pitch + _dot / 2, y), _dot / 2, dotPaint);
    }
    // The pill: its leading edge runs ahead over the first half of a page,
    // its trailing edge catches up over the second.
    final p = page.value.clamp(0.0, (count - 1).toDouble());
    final from = p.floor().clamp(0, math.max(0, count - 2));
    final f = (p - from).clamp(0.0, 1.0);
    final x = _padX + from * _pitch;
    final ease = Curves.easeInOut;
    final left = x + _pitch * ease.transform(((f - 0.5) * 2).clamp(0.0, 1.0));
    final right = x + _dot + _pitch * ease.transform((f * 2).clamp(0.0, 1.0));
    // Thinner while stretched, as liquid would be.
    final stretch = (right - left - _dot) / _pitch;
    final thickness = _dot * (1 - 0.18 * math.sin(stretch.clamp(0.0, 1.0) * math.pi));
    final pill = RRect.fromLTRBR(left, y - thickness / 2, right, y + thickness / 2, Radius.circular(thickness / 2));
    canvas.drawRRect(pill, Paint()..color = active);
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.active != active || oldDelegate.idle != idle;
}

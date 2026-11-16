import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';
import 'overlay_scope.dart';

/// The glass of a magnifying lens: clear, unfrosted, with a lit rim that
/// bends the edge of what it magnifies.
class _LensGlass extends StatelessWidget {
  const _LensGlass({
    required this.size,
    required this.radius,
    required this.magnification,
    this.focus = Offset.zero,
    this.child,
  });

  final Size size;
  final double radius;
  final double magnification;

  /// Where the magnified spot lies from the lens's middle.
  final Offset focus;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final shadowRadius = radius.isFinite ? radius : size.shortestSide / 2;
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(shadowRadius),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, theme.isDark ? 0.45 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LiquidGlassBox(
          radius: radius,
          style: GlassStyle(
            // A magnifier is clear: the faintest wash of the page's glass.
            tint: theme.glass.withValues(alpha: theme.glass.a * 0.12),
            edge: theme.edge,
            drop: const Color(0x00000000),
            rimShine: theme.isDark ? 0.3 : 0.6,
            blur: 0,
            saturation: 1.1,
            bend: theme.glassBend,
            dispersion: theme.glassDispersion,
            spec: LensSpec.glass,
            magnification: magnification,
            magnifyOffset: focus,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A draggable glass lens that magnifies what's under it, as the magnifier
/// on glisse.kelvinzhang.ca: its middle shows the backdrop enlarged, and its
/// bezel bends the edge of that.
///
/// It fills its parent, which is the area it can be dragged over, and lays
/// the lens in it. It magnifies a [GlassBackdrop]'s background (or, on
/// Impeller, the live backdrop); give the parent one.
class GlassMagnifier extends StatefulWidget {
  /// Creates a magnifier.
  const GlassMagnifier({
    super.key,
    this.size = 120,
    this.magnification = 1.5,
    this.borderRadius = double.infinity,
    this.position,
    this.onMoved,
    this.child,
    this.aspectRatio = 1,
  });

  /// The lens's width; its height is [size] / [aspectRatio].
  final double size;

  /// How much the lens enlarges what's under its middle.
  final double magnification;

  /// The lens's corner radius; [double.infinity] for a circle or capsule.
  final double borderRadius;

  /// The lens's width over its height.
  final double aspectRatio;

  /// Where the lens's top-left corner sits in the area. Leave it null for
  /// the magnifier to keep its own, starting in the middle.
  final Offset? position;

  /// Called as the lens is dragged, with where its top-left corner is now.
  final ValueChanged<Offset>? onMoved;

  /// Laid over the lens, such as a crosshair.
  final Widget? child;

  @override
  State<GlassMagnifier> createState() => _GlassMagnifierState();
}

class _GlassMagnifierState extends State<GlassMagnifier> with SingleTickerProviderStateMixin {
  Offset? _own;
  // Where a drag has the lens now: moves can come faster than frames.
  Offset? _dragging;
  late final GlassSpring _lift = GlassSpring(vsync: this, stiffness: 600, damping: 30);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lift.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassMagnifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A parent that places the lens has the last word on where a drag is.
    if (_dragging != null && widget.position != null && widget.position != oldWidget.position) {
      _dragging = widget.position;
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lens = Size(widget.size, widget.size / widget.aspectRatio);
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final max = Offset(
          (area.width - lens.width).clamp(0, double.infinity),
          (area.height - lens.height).clamp(0, double.infinity),
        );
        Offset clampTo(Offset o) => Offset(o.dx.clamp(0, max.dx), o.dy.clamp(0, max.dy));
        final at = clampTo(widget.position ?? _own ?? Offset(max.dx / 2, max.dy / 2));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              child: Semantics(
                label: 'Magnifier',
                child: GestureDetector(
                  onPanStart: (_) {
                    _dragging = at;
                    _lift.set(1);
                  },
                  onPanUpdate: (details) {
                    final next = clampTo((_dragging ?? at) + details.delta);
                    _dragging = next;
                    if (widget.position == null) setState(() => _own = next);
                    widget.onMoved?.call(next);
                  },
                  onPanEnd: (_) {
                    _dragging = null;
                    _lift.set(0);
                  },
                  onPanCancel: () {
                    _dragging = null;
                    _lift.set(0);
                  },
                  child: AnimatedBuilder(
                    animation: _lift,
                    builder: (context, child) => Transform.scale(scale: 1 + 0.06 * _lift.value, child: child),
                    child: _LensGlass(
                      size: lens,
                      radius: widget.borderRadius,
                      magnification: widget.magnification,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A loupe that rises over a long press and follows the finger, as iOS's
/// text loupe: a glass capsule a little above the finger, magnifying what's
/// under the finger.
///
/// The press must start in the region, but the loupe then floats in the
/// app's overlay and follows the finger anywhere on screen.
///
/// Like [GlassMagnifier], it magnifies a [GlassBackdrop]'s background, or
/// on Impeller the live backdrop, which includes [child].
class GlassLoupeRegion extends StatefulWidget {
  /// Creates a loupe region around [child].
  const GlassLoupeRegion({
    super.key,
    required this.child,
    this.size = const Size(120, 72),
    this.magnification = 1.6,
    this.lift = 72,
  });

  /// What the loupe magnifies.
  final Widget child;

  /// The loupe's size.
  final Size size;

  /// How much the loupe enlarges what is under the finger.
  final double magnification;

  /// How far above the finger the loupe's middle sits.
  final double lift;

  @override
  State<GlassLoupeRegion> createState() => _GlassLoupeRegionState();
}

class _GlassLoupeRegionState extends State<GlassLoupeRegion> with SingleTickerProviderStateMixin {
  // Where the finger is, in the overlay's coordinates when the loupe floats
  // in one, else in the region's.
  Offset? _at;
  OverlayEntry? _entry;
  GlassOverlayContext? _carried;
  late final GlassSpring _shown = GlassSpring(vsync: this, stiffness: 520, damping: 34)..addListener(_onShown);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _removeEntry();
    _shown.dispose();
    super.dispose();
  }

  void _onShown() {
    if (_shown.value <= 0.001 && !_shown.isMoving && _shown.target == 0) _removeEntry();
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }

  // The finger in the overlay's coordinates, or null without an overlay.
  Offset? _inOverlay(Offset global) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global);
  }

  void _show(LongPressStartDetails details) {
    final floating = _inOverlay(details.globalPosition);
    if (floating != null && _entry == null) {
      // The loupe floats over everything, so the region's bounds and its
      // ancestors' clips don't hold it in.
      _carried = GlassOverlayContext.of(context);
      _entry = OverlayEntry(builder: (context) => _carried!.wrap(_floatingLoupe()));
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    }
    setState(() => _at = floating ?? details.localPosition);
    _entry?.markNeedsBuild();
    _shown.set(1);
  }

  void _move(LongPressMoveUpdateDetails details) {
    setState(() => _at = _entry != null ? (_inOverlay(details.globalPosition) ?? _at) : details.localPosition);
    _entry?.markNeedsBuild();
  }

  void _hide() => _shown.set(0);

  Widget _loupe() => _LensGlass(
    size: widget.size,
    radius: double.infinity,
    magnification: widget.magnification,
    // Held above the finger, it shows what's under the finger.
    focus: Offset(0, widget.lift),
  );

  // The loupe at [_at], rising and fading in with [_shown].
  Widget _placed() {
    return AnimatedBuilder(
      animation: _shown,
      builder: (context, child) {
        final t = _shown.value;
        final at = _at;
        if (t <= 0.001 || at == null) return const SizedBox.shrink();
        return Positioned(
          left: at.dx - widget.size.width / 2,
          top: at.dy - widget.lift - widget.size.height / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.6 + 0.4 * t, alignment: Alignment.bottomCenter, child: child),
            ),
          ),
        );
      },
      child: _loupe(),
    );
  }

  Widget _floatingLoupe() => Stack(children: [_placed()]);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Long presses anywhere in the region count, over the child's content
      // or not, and still reach the child.
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _show,
      onLongPressMoveUpdate: _move,
      onLongPressEnd: (_) => _hide(),
      onLongPressCancel: _hide,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          // Without an overlay to float in, the loupe stays in the region.
          if (_entry == null && _at != null) _placed(),
        ],
      ),
    );
  }
}

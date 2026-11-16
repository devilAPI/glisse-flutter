// The engine shared by GlassTabBar and GlassSegmentedControl: a row of
// choices with one selected, under a selection that springs between them,
// follows a drag, and lifts into a lens while held. A port of Glisse's
// segments.tsx and its .lg-tab-bar / .lg-segmented styles.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/content_lens.dart';
import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';
import '../rendering/shadows.dart';

/// One choice: a tab bar's tab, which may have an icon, or a segment.
@immutable
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;

  /// An icon drawn above the label, as in an iOS tab bar.
  final IconData? icon;
}

/// Which of the two a [SegmentsView] draws.
enum SegmentsKind { tabBar, segmented }

// Springs: the slide's stiffness and damping, then the lift's.
const List<double> _rest = [1024, 58.9, 676, 47.8];
const List<double> _drag = [2500, 94, 576, 44.2];
// How far the lens lifts before it drops under the labels on a light page.
const double _under = 0.5;

/// Sizes of a bar, as Glisse's CSS sets them.
class _Metrics {
  const _Metrics({
    required this.tabWidth,
    required this.tabHeight,
    required this.inset,
    required this.thumbInset,
    required this.growX,
    required this.growY,
    required this.fontSize,
    required this.iconSize,
  });

  final double tabWidth;
  final double tabHeight;

  /// The bar's padding.
  final double inset;

  /// The selection's gap from its slot's edges.
  final double thumbInset;
  final double growX;
  final double growY;
  final double fontSize;
  final double iconSize;

  static const _Metrics tabBar =
      _Metrics(tabWidth: 84, tabHeight: 32, inset: 4, thumbInset: 0, growX: 27, growY: 20, fontSize: 14, iconSize: 0);
  static const _Metrics tabBarIcons =
      _Metrics(tabWidth: 72, tabHeight: 52, inset: 4, thumbInset: 0, growX: 24, growY: 16, fontSize: 10, iconSize: 26);
  static const _Metrics segmented =
      _Metrics(tabWidth: 84, tabHeight: 32, inset: 0, thumbInset: 2, growX: 24, growY: 16, fontSize: 13, iconSize: 0);
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.to);

  /// -1, 1, or the first (-2) or last (2).
  final int to;
}

/// A row of choices under a selection that lifts into a lens while held.
/// Only [GlassTabBar] and [GlassSegmentedControl] use it.
class SegmentsView<T> extends StatefulWidget {
  const SegmentsView({
    super.key,
    required this.kind,
    required this.items,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.mode = GlassMode.auto,
  });

  final SegmentsKind kind;
  final List<GlassSegment<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? semanticLabel;
  final GlassMode mode;

  @override
  State<SegmentsView<T>> createState() => _SegmentsViewState<T>();
}

class _Gesture {
  _Gesture({required this.pointer, required this.x, required this.anchor});

  final int pointer;
  final double x;
  final double anchor;
  double dx = 0;
  bool moved = false;
}

class _SegmentsViewState<T> extends State<SegmentsView<T>> with TickerProviderStateMixin {
  late final GlassSpring _x = GlassSpring(vsync: this, stiffness: _rest[0], damping: _rest[1]);
  late final GlassSpring _lift = GlassSpring(vsync: this, stiffness: _rest[2], damping: _rest[3]);
  // Where the pointer is across the bar, 0 to 1, for the lifted bar's glow.
  final ValueNotifier<double> _glow = ValueNotifier<double>(0.2);
  late final Listenable _repaint = Listenable.merge([_x, _lift, _glow, GlassShaders.ready]);

  ui.FragmentShader? _lensShader;
  ui.FragmentShader? _rimShader;
  _Gesture? _gesture;
  bool _shown = false;
  bool _focused = false;
  final Map<String, TextPainter> _painters = {};
  GlassThemeData? _paintedTheme;
  TextStyle _ambient = const TextStyle();

  bool get _segmented => widget.kind == SegmentsKind.segmented;

  /// Whether the lifted lens has dropped under the labels, as Glisse's does
  /// on a light page: a segmented control's from the press, a tab bar's
  /// once it's half lifted.
  bool get lensUnder {
    final lift = _lift.value;
    return _segmented ? (_gesture != null || lift > 0.01) : lift > _under;
  }

  // The lens as placed: the selection at the spring's x, grown with its lift.
  Rect _lensRect() {
    final m = _metrics;
    final lift = _lift.value;
    final width = m.tabWidth - 2 * m.thumbInset;
    final height = m.tabHeight - 2 * m.thumbInset;
    final selection = Rect.fromLTWH(m.inset + m.thumbInset + _x.value, m.inset + m.thumbInset, width, height);
    return Rect.fromCenter(
      center: selection.center,
      width: width * (1 + m.growX / width * lift),
      height: height * (1 + m.growY / height * lift),
    );
  }

  // On a light page the lifted lens also bends what's behind it, the bar's
  // glass and the page, as Glisse's does where the browser can: a segmented
  // control's with a squircle bezel pushed outwards, at full strength from
  // the press; a tab bar's with its label lens, unlit, growing once it has
  // dropped under the labels.
  Widget _backdropLens(GlassThemeData theme) {
    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
        final hidden = _active < 0 && _gesture == null;
        if (theme.lensShine >= 0 || hidden || !lensUnder) return const SizedBox.shrink();
        final m = _metrics;
        final rect = _lensRect();
        final LensSpec spec;
        final double bend;
        final double amount;
        final double blur;
        if (_segmented) {
          final base = math.min(m.tabWidth, m.tabHeight) - 2 * m.thumbInset;
          final bezel = (base * 0.12).clamp(4.0, 10.0);
          final thickness = (base * 0.2).clamp(8.0, 24.0);
          spec = LensSpec(strength: 1, dispersion: 0.35, depth: bezel, bezel: true);
          // Its rim pulls about 1.12 times the glass's thickness at the edge.
          bend = 2 * 1.12 * thickness / bezel;
          amount = 1;
          blur = 0;
        } else {
          spec = LensSpec.tab;
          bend = theme.tabBend ?? spec.strength;
          amount = ((_lift.value - _under) / (1 - _under)).clamp(0.0, 1.0);
          blur = spec.blur * amount;
        }
        if (amount <= 0) return const SizedBox.shrink();
        // Kept to the bar, whose glass it bends, in every mode: the rim and
        // fill the painter draws still reach past it as the lens grows.
        return ClipRRect(
          borderRadius: BorderRadius.circular(m.tabHeight / 2 + m.inset),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: LiquidGlassBox(
                    radius: double.infinity,
                    style: GlassStyle(
                      tint: const Color(0x00000000),
                      edge: const Color(0x00000000),
                      drop: const Color(0x00000000),
                      rimShine: 0,
                      blur: blur,
                      saturation: 1,
                      bend: bend,
                      dispersion: _segmented ? 0.35 : (theme.tabDispersion ?? spec.dispersion),
                      spec: spec,
                      rim: LensRim.none,
                      amount: amount,
                      mode: widget.mode,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _icons => !_segmented && widget.items.any((item) => item.icon != null);

  _Metrics get _metrics => _segmented ? _Metrics.segmented : (_icons ? _Metrics.tabBarIcons : _Metrics.tabBar);

  int get _active => widget.items.indexWhere((item) => item.value == widget.value);

  double get _slot => _metrics.tabWidth;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    GlassShaders.load();
    _settle(instant: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _x.reduceMotion = reduce;
    _lift.reduceMotion = reduce;
  }

  @override
  void didUpdateWidget(SegmentsView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameItems = _sameItems(oldWidget.items, widget.items);
    if (!sameItems) {
      for (final painter in _painters.values) {
        painter.dispose();
      }
      _painters.clear();
      // A press on items that are gone can't choose among them.
      if (_gesture != null) {
        _gesture = null;
        _lift.set(0);
      }
    }
    if (oldWidget.value != widget.value || !sameItems) _settle();
  }

  bool _sameItems(List<GlassSegment<T>> a, List<GlassSegment<T>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].label != b[i].label || a[i].icon != b[i].icon) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _x.dispose();
    _lift.dispose();
    _glow.dispose();
    _lensShader?.dispose();
    _rimShader?.dispose();
    for (final painter in _painters.values) {
      painter.dispose();
    }
    super.dispose();
  }

  void _move(double target, bool lifted, {bool instant = false}) {
    final springs = _gesture != null ? _drag : _rest;
    _x.tune(springs[0], springs[1]);
    _lift.tune(springs[2], springs[3]);
    _x.set(target, instant: instant);
    _lift.set(lifted ? 1 : 0, instant: instant);
  }

  void _settle({bool instant = false}) {
    if (_gesture != null) return;
    final active = _active;
    final show = active >= 0;
    if (show) _move(active * _slot, false, instant: instant || !_shown);
    _shown = show;
    if (mounted) setState(() {});
  }

  double _position(double dx) {
    final gesture = _gesture!;
    return (gesture.anchor + dx).clamp(0.0, _slot * math.max(0, widget.items.length - 1)).toDouble();
  }

  void _setGlow(Offset local) {
    final width = widget.items.length * _slot + 2 * _metrics.inset;
    _glow.value = (local.dx / width).clamp(0.0, 1.0);
  }

  void _down(PointerDownEvent event) {
    if (!_enabled || _gesture != null || widget.items.isEmpty) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    final m = _metrics;
    final local = event.localPosition;
    final index = ((local.dx - m.inset) / _slot).floor();
    if (index < 0 || index >= widget.items.length) return;
    _gesture = _Gesture(pointer: event.pointer, x: local.dx, anchor: index * _slot);
    _setGlow(local);
    _move(index * _slot, true, instant: !_shown);
    _shown = true;
    setState(() {});
  }

  void _pointerMove(PointerMoveEvent event) {
    final gesture = _gesture;
    if (gesture == null || event.pointer != gesture.pointer) return;
    gesture.dx = event.localPosition.dx - gesture.x;
    if (!gesture.moved && gesture.dx.abs() > 6) gesture.moved = true;
    if (gesture.moved) _move(_position(gesture.dx), true);
    _setGlow(event.localPosition);
  }

  void _up(PointerUpEvent event) {
    final gesture = _gesture;
    if (gesture == null || event.pointer != gesture.pointer) return;
    if (widget.items.isEmpty) {
      _gesture = null;
      _settle();
      return;
    }
    final index = (_position(gesture.moved ? gesture.dx : 0) / _slot).round().clamp(0, widget.items.length - 1);
    _gesture = null;
    // A drag selects wherever it leaves the lens; a tap only counts if it
    // ends on the bar, as with a button.
    final height = context.size?.height ?? 0;
    final y = event.localPosition.dy;
    final near = y >= -24 && y <= height + 24;
    if (gesture.moved || near) {
      final item = widget.items[index];
      if (item.value != widget.value) {
        widget.onChanged?.call(item.value);
        // Use the new value once it's built, or settle back if declined.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _settle();
        });
        SchedulerBinding.instance.ensureVisualUpdate();
        // Start settling towards the choice now, so the lens never heads back.
        _move(index * _slot, false);
        setState(() {});
        return;
      }
      widget.onChanged?.call(item.value);
    }
    _settle();
  }

  void _cancel(PointerCancelEvent event) {
    final gesture = _gesture;
    if (gesture == null || event.pointer != gesture.pointer) return;
    _gesture = null;
    _settle();
  }

  void _select(int index) {
    if (!_enabled || widget.items.isEmpty) return;
    widget.onChanged?.call(widget.items[index].value);
  }

  void _keyMove(int to) {
    final n = widget.items.length;
    if (n == 0) return;
    final current = _active < 0 ? 0 : _active;
    final index = switch (to) {
      -2 => 0,
      2 => n - 1,
      _ => (current + to + n) % n,
    };
    _select(index);
  }

  TextPainter _label(int index, Color color, FontWeight weight, GlassThemeData theme) {
    if (_paintedTheme != theme) {
      for (final painter in _painters.values) {
        painter.dispose();
      }
      _painters.clear();
      _paintedTheme = theme;
    }
    final item = widget.items[index];
    final key = '$index|${color.toARGB32()}|${weight.value}';
    return _painters.putIfAbsent(key, () {
      final m = _metrics;
      final style = _ambient.merge(theme.textStyle).copyWith(fontSize: m.fontSize, fontWeight: weight, color: color);
      return TextPainter(
        text: TextSpan(text: item.label, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: m.tabWidth - 4);
    });
  }

  TextPainter? _icon(int index, Color color, GlassThemeData theme) {
    final icon = widget.items[index].icon;
    if (icon == null) return null;
    final key = 'icon|$index|${color.toARGB32()}';
    return _painters.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontFamilyFallback: icon.fontFamilyFallback,
            fontSize: _metrics.iconSize,
            height: 1,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    // Labels take the ambient font, as Text would.
    final ambient = DefaultTextStyle.of(context).style;
    if (ambient != _ambient) {
      _ambient = ambient;
      _paintedTheme = null;
    }
    final m = _metrics;
    final n = widget.items.length;
    final width = n * m.tabWidth + 2 * m.inset;
    final height = m.tabHeight + 2 * m.inset;
    final radius = m.tabHeight / 2 + m.inset;
    final active = _active;

    final glass = LiquidGlassBox(
      radius: radius,
      style: GlassStyle(
        tint: _segmented ? Color.alphaBlend(theme.segmentTrack, theme.glass) : theme.glass,
        edge: theme.edge,
        drop: theme.drop,
        rimShine: theme.rimShine,
        blur: theme.blur,
        saturation: theme.saturation,
        bend: theme.glassBend,
        dispersion: theme.glassDispersion,
        spec: LensSpec.glass,
        mode: widget.mode,
      ),
      // In the bar's glass, so it bends the bar's glass as well as the page.
      child: _backdropLens(theme),
    );

    final tabs = <Widget>[
      for (var i = 0; i < n; i++)
        SizedBox(
          width: m.tabWidth,
          height: m.tabHeight,
          child: Semantics(
            label: widget.items[i].label,
            selected: _segmented ? null : i == active,
            button: _segmented ? null : true,
            inMutuallyExclusiveGroup: _segmented ? true : null,
            checked: _segmented ? i == active : null,
            enabled: _enabled,
            onTap: _enabled ? () => _select(i) : null,
            child: const SizedBox.expand(),
          ),
        ),
    ];

    Widget bar = SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: glass),
          Positioned.fill(
            child: CustomPaint(
              painter: _SegmentsPainter<T>(
                state: this,
                theme: theme,
                devicePixelRatio: dpr,
                focused: _focused,
                repaint: _repaint,
              ),
            ),
          ),
          Positioned(
            left: m.inset,
            top: m.inset,
            child: Row(
              // Laid out left to right, as the selection is painted and dragged.
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: tabs,
            ),
          ),
        ],
      ),
    );

    bar = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _pointerMove,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      // Claims horizontal drags, so a scrolling parent leaves them to the bar.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _enabled ? (_) {} : null,
        onHorizontalDragUpdate: _enabled ? (_) {} : null,
        child: bar,
      ),
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      explicitChildNodes: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(1),
          SingleActivator(LogicalKeyboardKey.home): _MoveIntent(-2),
          SingleActivator(LogicalKeyboardKey.end): _MoveIntent(2),
        },
        actions: <Type, Action<Intent>>{
          _MoveIntent: CallbackAction<_MoveIntent>(onInvoke: (intent) {
            _keyMove(intent.to);
            return null;
          }),
        },
        child: Opacity(opacity: _enabled ? 1 : 0.35, child: bar),
      ),
    );
  }
}

class _SegmentsPainter<T> extends CustomPainter {
  _SegmentsPainter({
    required this.state,
    required this.theme,
    required this.devicePixelRatio,
    required this.focused,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _SegmentsViewState<T> state;
  final GlassThemeData theme;
  final double devicePixelRatio;
  final bool focused;

  bool get segmented => state._segmented;

  /// The colour labels show under the selection.
  Color get selectedColor => segmented ? theme.segmentLabel : (state._icons ? theme.fill : theme.foreground);

  /// Every other label's colour.
  Color get baseColor => segmented ? theme.segmentLabel : (state._icons ? theme.foreground : theme.muted);

  FontWeight weightFor(int index, int active) {
    if (state._icons) return FontWeight.w500;
    if (segmented && index == active) return FontWeight.w500;
    return FontWeight.w400;
  }

  // Draws every label, each in the colour [colorFor] gives (or none).
  void paintLabels(Canvas canvas, Color? Function(int index) colorFor, int active) {
    final m = state._metrics;
    for (var i = 0; i < state.widget.items.length; i++) {
      final color = colorFor(i);
      if (color == null || color.a == 0) continue;
      final slot = Rect.fromLTWH(m.inset + i * m.tabWidth, m.inset, m.tabWidth, m.tabHeight);
      final text = state._label(i, color, weightFor(i, active), theme);
      final icon = state._icon(i, color, theme);
      if (icon == null) {
        text.paint(canvas, slot.center - Offset(text.width / 2, text.height / 2));
      } else {
        const gap = 1.0;
        final total = icon.height + gap + text.height;
        final top = slot.center.dy - total / 2;
        icon.paint(canvas, Offset(slot.center.dx - icon.width / 2, top));
        text.paint(canvas, Offset(slot.center.dx - text.width / 2, top + icon.height + gap));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = state._metrics;
    final active = state._active;
    final gesture = state._gesture;
    final x = state._x.value;
    final lift = state._lift.value;
    final lifted = lift.clamp(0.0, 1.0);
    final hidden = active < 0 && gesture == null;
    final away = active < 0 || (x - active * m.tabWidth).abs() > 0.5;
    final light = theme.lensShine < 0;
    final barRect = Offset.zero & size;
    final barRRect = roundedRect(barRect, m.tabHeight / 2 + m.inset);

    // The selection at rest, and the lens it lifts into.
    final width = m.tabWidth - 2 * m.thumbInset;
    final height = m.tabHeight - 2 * m.thumbInset;
    final selection = Rect.fromLTWH(m.inset + m.thumbInset + x, m.inset + m.thumbInset, width, height);
    final sx = 1 + (m.growX / width) * lift;
    final sy = 1 + (m.growY / height) * lift;
    final lens = Rect.fromCenter(center: selection.center, width: width * sx, height: height * sy);
    final lensRRect = roundedRect(lens, double.infinity);

    // The lifted bar's glow, under the labels: a segmented control's too.
    if (lifted > 0) {
      final center = Offset(state._glow.value * size.width, size.height / 2);
      final glow = const RadialGradient(
        colors: [Color.fromRGBO(255, 255, 255, 0.09), Color.fromRGBO(255, 255, 255, 0.045), Color(0x00FFFFFF)],
        stops: [0, 0.6, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 260));
      canvas.save();
      canvas.clipRRect(barRRect);
      canvas.drawRect(
          barRect,
          Paint()
            ..shader = glow
            ..color = Color.fromRGBO(0, 0, 0, lifted));
      canvas.restore();
    }

    if (!hidden) {
      // The lens's shadow, faded in with its lift.
      final drop = theme.lensDrop;
      if (drop.a > 0 && lifted > 0) {
        paintDropShadow(canvas, lensRRect,
            color: drop.withValues(alpha: drop.a * lifted), offset: const Offset(0, 7), blur: 11);
      }
      // A segmented control's thumb, which fades as the lens lifts.
      if (segmented) {
        final thumb = theme.segmentThumb;
        final opacity = (1 - lifted * 2).clamp(0.0, 1.0);
        if (opacity > 0) {
          canvas.drawRRect(lensRRect, Paint()..color = thumb.withValues(alpha: thumb.a * opacity));
        }
      }
      // The lifted lens's fill.
      final fill = segmented ? theme.segmentLens : theme.lens;
      final under = light && !segmented ? ((lift - _under) / (1 - _under)).clamp(0.0, 1.0) : lifted;
      if (fill.a > 0 && under > 0) {
        canvas.drawRRect(lensRRect, Paint()..color = fill.withValues(alpha: fill.a * under));
      }
    }

    // The lifted lens's rim: iOS's brighter one on a light page.
    void paintRim() {
      final rimShader = state._rimShader ??= GlassShaders.create();
      // As Glisse's data-refracting: at full strength from the press until
      // the lens has settled.
      final refracting = state._gesture != null || lift > 0.01;
      if (rimShader == null || !refracting || hidden) return;
      LensDraw(
        rect: lens,
        shape: Size(width, height),
        radius: double.infinity,
        spec: segmented ? LensSpec.segment : LensSpec.tab,
        devicePixelRatio: devicePixelRatio,
        rim: light ? LensRim.brightSelection : LensRim.selection,
      ).apply(rimShader, image: emptyImage);
      canvas.drawRect(lens.inflate(1), Paint()..shader = rimShader);
    }

    // On a light page the lifted lens drops under the labels, as Glisse's
    // does: a segmented control's from the press, a tab bar's once it's
    // half lifted. Its rim goes with it.
    final rimUnder = light && state.lensUnder;
    if (rimUnder) paintRim();

    final lensShader = state._lensShader ??= GlassShaders.create();
    final lensing = lift > 0.01 && lensShader != null && !hidden;

    Color? realColor(int i) {
      // Over the selected tab, the selection draws its label (the tint at
      // rest, the lens's copy when lifted), so the tab's own hides.
      if (!segmented && !away && i == active && !hidden) return null;
      return baseColor;
    }

    if (lensing) {
      final room = Rect.fromLTRB(
          -m.growX / 2 - 4, -m.growY / 2 - 4, size.width + m.growX / 2 + 4, size.height + m.growY / 2 + 4);
      canvas.saveLayer(room, Paint());
      paintLabels(canvas, realColor, active);
      cutOut(canvas, lensRRect);
      canvas.restore();

      // Through the lens, every label in the selected colour, bent at its rim.
      final image = recordImage(room.size, devicePixelRatio, (canvas) {
        canvas.translate(-room.left, -room.top);
        paintLabels(canvas, (_) => selectedColor, active);
      });
      final spec = segmented ? LensSpec.segment : LensSpec.tab;
      final shape = Size(width, height);
      final strength = segmented ? theme.segmentBend : theme.tabBend;
      final reach = spec.reachOf(shape, strengthOverride: strength, dark: !light) *
          (math.min(lens.width, lens.height) / math.min(width, height)) *
          lifted;
      paintContentLens(
        canvas,
        lensShader,
        image: image,
        imageRect: room,
        draw: LensDraw(
          rect: lens,
          shape: shape,
          radius: double.infinity,
          spec: spec,
          devicePixelRatio: devicePixelRatio,
          reach: reach,
          dispersion: segmented ? null : theme.tabDispersion,
          // Softens only what the rim bends, growing as the lens lifts.
          blur: spec.blur * lifted,
          softensBend: true,
          shine: theme.lensShine,
          light: light ? LensLight.light : LensLight.dark,
          inkPage: light ? Brightness.light : Brightness.dark,
        ),
      );
      image.dispose();
    } else {
      paintLabels(canvas, realColor, active);
      // The tint: the labels again in the selected colour, seen only through
      // the selection.
      if (!segmented && !hidden) {
        canvas.save();
        canvas.clipRRect(lensRRect);
        paintLabels(canvas, (_) => selectedColor, active);
        canvas.restore();
      }
    }

    if (!hidden) {
      // The tab bar's selection at rest, which fades as the lens lifts.
      if (!segmented) {
        final rest = (1 - lift / _under).clamp(0.0, 1.0);
        final pill = theme.selection;
        if (rest > 0) canvas.drawRRect(lensRRect, Paint()..color = pill.withValues(alpha: pill.a * rest));
      }
      if (!rimUnder) paintRim();
    }

    // As Glisse's focus-visible outline: 2px, inset 2px, round the focused
    // tab, which is the selected one.
    if (focused && state.widget.items.isNotEmpty) {
      final index = active < 0 ? 0 : active;
      final slot = Rect.fromLTWH(m.inset + index * m.tabWidth, m.inset, m.tabWidth, m.tabHeight);
      canvas.drawRRect(
        roundedRect(slot, m.tabHeight / 2).deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.ring,
      );
    }
  }

  @override
  // The items, the value and the gesture all live on the state.
  bool shouldRepaint(_SegmentsPainter<T> oldDelegate) => true;
}

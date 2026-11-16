import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/shadows.dart';
import 'hairline.dart';
import 'menu.dart';
import 'overlay_scope.dart';

/// A menu that a long press (or a right-click) on [child] opens, as iOS's
/// context menus: the child lifts out of a blurred, dimmed page and a menu
/// of [items] opens below it, or above it when there's no room.
///
/// A finger held down after the menu opens can slide onto a row and let go
/// to choose it. A tap outside or the Escape key closes the menu.
///
/// The lifted preview builds [child] a second time, in the app's overlay;
/// give a [previewBuilder] to show something else, such as a larger image.
class GlassContextMenu extends StatefulWidget {
  /// Creates a context menu around [child].
  const GlassContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.previewBuilder,
    this.semanticLabel = 'Menu',
    this.enabled = true,
    this.menuWidth = 250,
    this.onOpenChanged,
  });

  /// The widget a long press or right-click opens the menu from.
  final Widget child;

  /// The rows: [GlassMenuItem]s and [GlassMenuSeparator]s.
  final List<GlassMenuEntry> items;

  /// Builds what lifts out of the page. Defaults to [child] at its own size.
  final WidgetBuilder? previewBuilder;

  /// Names the menu for assistive technology.
  final String semanticLabel;

  /// Whether a long press opens the menu.
  final bool enabled;

  /// The widest the menu grows to.
  final double menuWidth;

  /// Called as the menu opens and closes. Not called when the menu is
  /// removed from the tree while open.
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<GlassContextMenu> createState() => _GlassContextMenuState();
}

class _GlassContextMenuState extends State<GlassContextMenu> with SingleTickerProviderStateMixin {
  // 0 is resting in the page, 1 lifted with the menu open.
  late final GlassSpring _shown = GlassSpring(vsync: this, stiffness: 420, damping: 32)..addListener(_onShown);
  final GlobalKey<_ContextOverlayState> _overlayKey = GlobalKey();
  OverlayEntry? _entry;
  bool _open = false;
  bool _pressing = false;
  bool _reduceMotion = false;
  Rect _anchor = Rect.zero;
  CapturedThemes? _themes;
  Size? _screen;
  FocusNode? _restore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shown.reduceMotion = _reduceMotion;
    // Turned or resized, the page moves under the preview: close.
    final screen = MediaQuery.maybeSizeOf(context);
    if (_open && _screen != null && screen != _screen) _later(_close);
    _screen = screen;
    _rebuildEntry();
  }

  @override
  void didUpdateWidget(GlassContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _open) _later(_close);
    // A press can't finish once disabled; no setState, as this is a build.
    if (!widget.enabled) _pressing = false;
    _rebuildEntry();
  }

  // Overlay changes can't be made while the tree builds.
  void _later(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _rebuildEntry() {
    final entry = _entry;
    if (entry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry == entry && entry.mounted) entry.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _onShown() {
    if (!_open && _entry != null && _shown.value <= 0.001 && !_shown.isMoving) _remove();
  }

  void _openMenu() {
    if (!widget.enabled || _open || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || overlayBox == null) return;
    _anchor = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    _restore = FocusManager.instance.primaryFocus;
    // The preview wears the page's text and icon styles, as its child does.
    _themes = InheritedTheme.capture(from: context, to: overlay.context);
    if (_entry == null) {
      final carried = GlassOverlayContext.of(context);
      _entry = OverlayEntry(builder: (context) => carried.wrap(_ContextOverlay(key: _overlayKey, menu: this)));
      overlay.insert(_entry!);
    } else {
      // Reopened on its way out: take it back up from where it is, and give
      // the keyboard back to its rows.
      _entry!.markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback((_) => _overlayKey.currentState?._focusFirst());
    }
    setState(() {
      _open = true;
      _pressing = false;
    });
    unawaited(HapticFeedback.mediumImpact());
    _shown
      ..tune(420, 32)
      ..set(1);
    widget.onOpenChanged?.call(true);
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _entry?.markNeedsBuild();
    final restore = _restore;
    _restore = null;
    if (restore != null && restore.context != null && restore.canRequestFocus) restore.requestFocus();
    widget.onOpenChanged?.call(false);
    _shown
      ..tune(600, 50)
      ..set(0);
    _onShown();
  }

  void _remove() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    // The child shows in the page again.
    if (mounted) setState(() {});
  }

  void _press(bool pressing) {
    if (_pressing == pressing || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _pressing = pressing; // Mid-build: the build under way shows it.
      return;
    }
    setState(() => _pressing = pressing);
  }

  @override
  Widget build(BuildContext context) {
    final lifted = _entry != null;
    final held = _pressing && !_reduceMotion;
    Widget child = AnimatedScale(
      // Held, the child sinks a little before it lifts, as on iOS.
      scale: held ? 0.97 : 1,
      duration: held ? kLongPressTimeout : const Duration(milliseconds: 200),
      curve: held ? Curves.easeInOut : Curves.easeOut,
      child: widget.child,
    );
    // The preview stands in for the child while it's lifted.
    child = Opacity(opacity: lifted ? 0 : 1, child: child);
    return Semantics(
      onLongPress: widget.enabled ? _openMenu : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.translucent,
        onLongPressDown: widget.enabled ? (_) => _press(true) : null,
        // Always set: a recognizer dropped mid-press, as when disabled,
        // cancels through the old callback during the build.
        onLongPressCancel: () => _press(false),
        onLongPressStart: widget.enabled ? (_) => _openMenu() : null,
        onLongPressMoveUpdate:
            widget.enabled ? (details) => _overlayKey.currentState?._track(details.globalPosition) : null,
        onLongPressEnd: widget.enabled ? (details) => _overlayKey.currentState?._release(details.globalPosition) : null,
        onSecondaryTapUp: widget.enabled ? (_) => _openMenu() : null,
        child: child,
      ),
    );
  }
}

enum _Slot { preview, menu }

const double _cardRadius = 20;
const double _margin = 12;
const double _gap = 10;

/// Which side of the preview the menu took, for it to grow from there.
class _Placement {
  bool above = false;
  bool fromLeft = true;
}

class _ContextOverlay extends StatefulWidget {
  const _ContextOverlay({super.key, required this.menu});

  final _GlassContextMenuState menu;

  @override
  State<_ContextOverlay> createState() => _ContextOverlayState();
}

class _ContextOverlayState extends State<_ContextOverlay> {
  final Map<int, GlobalKey> _rowKeys = {};
  final Map<int, FocusNode> _focusNodes = {};
  final FocusNode _root = FocusNode(debugLabel: 'GlassContextMenu');
  final _Placement _placement = _Placement();
  int? _pointer;
  int? _lit;
  int? _focusVisible;

  _GlassContextMenuState get _menu => widget.menu;
  List<GlassMenuEntry> get _items => _menu.widget.items;

  @override
  void initState() {
    super.initState();
    // The first row takes focus as the menu opens, so the keyboard starts there.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirst());
  }

  void _focusFirst() {
    if (!mounted || !_menu._open) return;
    final first = _enabledRows().firstOrNull;
    (first == null ? _root : _focusNode(first)).requestFocus();
  }

  @override
  void dispose() {
    _root.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<int> _enabledRows() {
    final rows = <int>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item is GlassMenuItem && item.enabled) rows.add(i);
    }
    return rows;
  }

  GlobalKey _rowKey(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  FocusNode _focusNode(int index) =>
      _focusNodes.putIfAbsent(index, () => FocusNode(debugLabel: 'GlassContextMenu row $index'));

  int? _rowAt(Offset global) {
    if (!_menu._open) return null;
    for (final index in _enabledRows()) {
      final box = _rowKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      if ((Offset.zero & box.size).contains(box.globalToLocal(global))) return index;
    }
    return null;
  }

  void _light(int? index) {
    if (_lit != index && mounted) setState(() => _lit = index);
  }

  void _select(int index) {
    if (!_menu._open || index >= _items.length) return;
    final item = _items[index];
    if (item is! GlassMenuItem || !item.enabled) return;
    _menu._close();
    item.onSelected?.call();
  }

  // The finger that opened the menu, still down, sliding over the rows.
  void _track(Offset global) => _light(_rowAt(global));

  void _release(Offset global) {
    final row = _rowAt(global);
    _light(null);
    if (row != null) _select(row);
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    _pointer = event.pointer;
    _light(_rowAt(event.position));
  }

  void _move(PointerEvent event) {
    if (_pointer == null) {
      if (event.kind == PointerDeviceKind.mouse) _light(_rowAt(event.position));
      return;
    }
    if (event.pointer == _pointer) _light(_rowAt(event.position));
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final row = _rowAt(event.position);
    _light(null);
    if (row != null) _select(row);
  }

  void _cancel([PointerEvent? event]) {
    if (event != null && event.pointer != _pointer) return;
    _pointer = null;
    _light(null);
  }

  bool _scrolled(ScrollStartNotification notification) {
    if (notification.dragDetails != null) _cancel();
    return false;
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _menu._close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _menu._close();
      return KeyEventResult.handled;
    }
    final moves = {
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
    };
    if (!moves.contains(key)) return KeyEventResult.ignored;
    final rows = _enabledRows();
    if (rows.isEmpty) return KeyEventResult.handled;
    _light(null);
    final focused = rows.indexWhere((i) => _focusNodes[i]?.hasFocus ?? false);
    final int next;
    if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = rows.length - 1;
    } else {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      next = focused < 0 ? (step > 0 ? 0 : rows.length - 1) : (focused + step + rows.length) % rows.length;
    }
    _focusNode(rows[next]).requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    final theme = GlassTheme.of(context);
    final media = MediaQuery.of(context);
    final shown = menu._shown;

    final scrim = AnimatedBuilder(
      animation: shown,
      builder: (context, _) {
        final t = _unit(shown.value);
        final dim = (theme.isDark ? const Color(0x59000000) : const Color(0x26000000));
        Widget layer = ColoredBox(color: dim.withValues(alpha: dim.a * t));
        if (t > 0.001) {
          layer = BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12 * t, sigmaY: 12 * t), child: layer);
        }
        return layer;
      },
    );

    final previewBuilder = menu.widget.previewBuilder;
    Widget preview = previewBuilder != null
        ? Builder(builder: previewBuilder)
        : FittedBox(fit: BoxFit.scaleDown, child: SizedBox.fromSize(size: menu._anchor.size, child: menu.widget.child));
    preview = menu._themes?.wrap(preview) ?? preview;
    // A copy, for show: the page's own child keeps its taps and semantics.
    preview = IgnorePointer(child: ExcludeSemantics(child: preview));
    preview = AnimatedBuilder(
      animation: shown,
      child: preview,
      builder: (context, child) {
        final t = shown.value;
        return Transform.scale(scale: 1 + 0.05 * t.clamp(0.0, 1.2), child: child);
      },
    );

    Widget card = _card(theme);
    card = AnimatedBuilder(
      animation: shown,
      child: card,
      builder: (context, child) {
        final t = shown.value;
        return Opacity(
          opacity: _unit(t / 0.6),
          child: _CornerScale(scale: 0.6 + 0.4 * t.clamp(0.0, 1.1), placement: _placement, child: child),
        );
      },
    );

    return IgnorePointer(
      ignoring: !menu._open,
      child: BlockSemantics(
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                label: 'Dismiss',
                onTap: menu._close,
                onDismiss: menu._close,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTap: menu._close,
                  onSecondaryTap: menu._close,
                  child: scrim,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomMultiChildLayout(
                delegate: _ContextLayout(
                  anchor: menu._anchor,
                  shown: shown,
                  padding: media.padding + EdgeInsets.only(bottom: media.viewInsets.bottom),
                  menuWidth: menu.widget.menuWidth,
                  placement: _placement,
                ),
                children: [
                  LayoutId(id: _Slot.preview, child: preview),
                  LayoutId(
                    id: _Slot.menu,
                    child: Semantics(
                      scopesRoute: true,
                      namesRoute: true,
                      explicitChildNodes: true,
                      label: menu.widget.semanticLabel,
                      child: Focus(focusNode: _root, onKeyEvent: _key, child: card),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(GlassThemeData theme) {
    final rows = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      switch (item) {
        case GlassMenuSeparator():
          rows.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
            child: SizedBox(height: hairline(context), child: ColoredBox(color: theme.separator)),
          ));
        case GlassMenuItem():
          rows.add(_row(theme, i, item));
      }
    }
    final content = NotificationListener<ScrollStartNotification>(
      onNotification: _scrolled,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    );
    // As a GlassMenu's card: frosted, rounded, with a soft shadow.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerHover: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: MouseRegion(
        onExit: (_) {
          if (_pointer == null) _light(null);
        },
        child: CustomPaint(
          painter: _CardShadow(theme.shadow),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
            child: BackdropFilter(
              filter: frostFilter(sigma: 22, saturation: 1.9),
              child: CustomPaint(
                painter: _CardFill(fill: theme.surface, edge: theme.surfaceEdge),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(GlassThemeData theme, int index, GlassMenuItem item) {
    final colour = item.destructive ? theme.destructive : theme.foreground;
    final lit = _lit == index || (_focusVisible == index && _lit == null);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (item.icon != null) ...[
              IconTheme.merge(data: IconThemeData(color: colour, size: 16), child: item.icon!),
              const SizedBox(width: 10),
            ],
            Expanded(child: item.label),
          ],
        ),
      ),
    );
    row = DefaultTextStyle.merge(style: TextStyle(color: colour, fontSize: 14), child: row);
    row = AnimatedContainer(
      duration: lit ? Duration.zero : const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: lit ? theme.highlight : theme.highlight.withValues(alpha: 0),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: row,
    );
    return Semantics(
      key: _rowKey(index),
      container: true,
      button: true,
      enabled: item.enabled,
      onTap: item.enabled ? () => _select(index) : null,
      child: FocusableActionDetector(
        focusNode: _focusNode(index),
        enabled: item.enabled,
        mouseCursor: item.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (shown) => setState(() {
          if (shown) {
            _focusVisible = index;
          } else if (_focusVisible == index) {
            _focusVisible = null;
          }
        }),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _select(index);
            return null;
          }),
        },
        child: Opacity(opacity: item.enabled ? 1 : 0.38, child: row),
      ),
    );
  }
}

double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

/// Lays the preview over its child's place in the page, moved only as far
/// as it must for the menu to fit beside it on screen, and the menu below
/// it, or above it when there's room only there.
class _ContextLayout extends MultiChildLayoutDelegate {
  _ContextLayout({
    required this.anchor,
    required this.shown,
    required this.padding,
    required this.menuWidth,
    required this.placement,
  }) : super(relayout: shown);

  final Rect anchor;
  final GlassSpring shown;
  final EdgeInsets padding;
  final double menuWidth;
  final _Placement placement;

  @override
  void performLayout(Size size) {
    final top = padding.top + _margin;
    final bottom = math.max(top, size.height - padding.bottom - _margin);
    final left = padding.left + _margin;
    final right = math.max(left, size.width - padding.right - _margin);
    final height = bottom - top;
    final width = right - left;

    final preview = layoutChild(_Slot.preview, BoxConstraints.loose(Size(width, height * 0.6)));
    final menuMax = math.max(height - preview.height - _gap, math.min(height, 160.0));
    final menu = layoutChild(
      _Slot.menu,
      BoxConstraints(maxWidth: math.min(menuWidth, width), maxHeight: math.max(0.0, menuMax)),
    );

    // Where the preview starts: centred on its child.
    final start = anchor.center - Offset(preview.width / 2, preview.height / 2);
    final x = start.dx.clamp(left, math.max(left, right - preview.width)).toDouble();
    final total = preview.height + _gap + menu.height;
    final double y;
    final bool above;
    final roomAbove = start.dy - top;
    final roomBelow = bottom - start.dy - preview.height;
    // Below when it fits; else above, when it fits there or there's more
    // room there; else below, the preview sliding up as far as it must.
    if (start.dy >= top && start.dy + total <= bottom) {
      y = start.dy;
      above = false;
    } else if (roomAbove >= _gap + menu.height || (roomAbove > roomBelow && total <= height)) {
      y = start.dy
          .clamp(top + _gap + menu.height, math.max(top + _gap + menu.height, bottom - preview.height))
          .toDouble();
      above = true;
    } else {
      y = start.dy.clamp(top, math.max(top, bottom - total)).toDouble();
      above = false;
    }

    final t = shown.value.clamp(0.0, 1.0);
    final at = Offset.lerp(start, Offset(x, y), t)!;
    positionChild(_Slot.preview, at);

    // The lifted preview stands a little taller; the menu keeps clear of it.
    final lift = preview.height * 0.025 * t;
    final fromLeft = anchor.center.dx <= size.width / 2;
    final menuX = (fromLeft ? at.dx : at.dx + preview.width - menu.width)
        .clamp(left, math.max(left, right - menu.width))
        .toDouble();
    var menuY = above ? at.dy - lift - _gap - menu.height : at.dy + preview.height + lift + _gap;
    menuY = menuY.clamp(top, math.max(top, bottom - menu.height)).toDouble();
    positionChild(_Slot.menu, Offset(menuX, menuY));
    placement
      ..above = above
      ..fromLeft = fromLeft;
  }

  @override
  bool shouldRelayout(_ContextLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.shown != shown ||
      oldDelegate.padding != padding ||
      oldDelegate.menuWidth != menuWidth ||
      oldDelegate.placement != placement;
}

/// Scales its child about the corner nearest the preview, read from
/// [placement] once layout has chosen it.
class _CornerScale extends SingleChildRenderObjectWidget {
  const _CornerScale({required this.scale, required this.placement, super.child});

  final double scale;
  final _Placement placement;

  @override
  _RenderCornerScale createRenderObject(BuildContext context) => _RenderCornerScale(scale, placement);

  @override
  void updateRenderObject(BuildContext context, _RenderCornerScale renderObject) {
    renderObject
      ..scale = scale
      ..placement = placement;
  }
}

class _RenderCornerScale extends RenderProxyBox {
  _RenderCornerScale(this._scale, this.placement);

  double _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsPaint();
  }

  _Placement placement;

  Matrix4 get _transform {
    final origin = Offset(placement.fromLeft ? 0 : size.width, placement.above ? size.height : 0);
    return Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..multiply(Matrix4.diagonal3Values(_scale, _scale, 1))
      ..multiply(Matrix4.translationValues(-origin.dx, -origin.dy, 0));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scale == 1) {
      layer = null;
      context.paintChild(child!, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child!, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}

class _CardShadow extends CustomPainter {
  _CardShadow(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintDropShadow(canvas, roundedRect(Offset.zero & size, _cardRadius),
        color: color, offset: const Offset(0, 12), blur: 40);
  }

  @override
  bool shouldRepaint(_CardShadow oldDelegate) => oldDelegate.color != color;
}

class _CardFill extends CustomPainter {
  _CardFill({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = roundedRect(Offset.zero & size, _cardRadius);
    canvas.drawRRect(rrect, Paint()..color = fill);
    paintInsetShadow(canvas, rrect, color: edge, spread: 0.5);
  }

  @override
  bool shouldRepaint(_CardFill oldDelegate) => oldDelegate.fill != fill || oldDelegate.edge != edge;
}

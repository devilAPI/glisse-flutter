import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/shadows.dart';
import 'button.dart';
import 'hairline.dart';

/// One entry of a [GlassMenu]: a [GlassMenuItem] or a [GlassMenuSeparator].
sealed class GlassMenuEntry {
  const GlassMenuEntry();
}

/// A row of a [GlassMenu].
class GlassMenuItem extends GlassMenuEntry {
  /// Creates a menu row; [onSelected] runs when it's chosen.
  const GlassMenuItem({
    required this.label,
    this.icon,
    this.onSelected,
    this.destructive = false,
    this.enabled = true,
  });

  /// The row's text.
  final Widget label;

  /// Shown before the label, at 16px.
  final Widget? icon;

  /// Called when the row is chosen. Null disables it.
  final VoidCallback? onSelected;

  /// Marks an action that deletes or can't be undone, in red.
  final bool destructive;

  /// Whether the row can be chosen; false greys it out.
  final bool enabled;
}

/// A thin line between groups of a [GlassMenu]'s rows.
class GlassMenuSeparator extends GlassMenuEntry {
  /// Creates a menu separator.
  const GlassMenuSeparator();
}

/// Which edge of its trigger a [GlassMenu] lines up with as it opens across it.
enum GlassMenuAlign {
  /// The trigger's start edge.
  start,

  /// The trigger's end edge.
  end,
}

/// A menu of actions behind a glass button, as iOS 26's: the glass grows out
/// of the trigger while the rows scale up from its centre and come into
/// focus. Held, the menu swells and follows the finger a little, and a plate
/// slides between the rows under it; letting go over a row chooses it.
class GlassMenu extends StatefulWidget {
  /// Creates a menu opened from a glass button.
  const GlassMenu({
    super.key,
    required this.items,
    required this.semanticLabel,
    this.icon,
    this.align = GlassMenuAlign.end,
  });

  /// The rows, in order.
  final List<GlassMenuEntry> items;

  /// Names the trigger and the menu for assistive technology.
  final String semanticLabel;

  /// The trigger's icon. Defaults to an ellipsis.
  final Widget? icon;

  /// The trigger edge the menu lines up with.
  final GlassMenuAlign align;

  @override
  State<GlassMenu> createState() => _GlassMenuState();
}

enum _Phase { closed, open, leaving }

double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

class _GlassMenuState extends State<GlassMenu> with TickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'GlassMenu trigger');
  late final GlassSpring _morph = GlassSpring(vsync: this, stiffness: 600, damping: 46)..addListener(_onMorph);
  OverlayEntry? _entry;
  _Phase _phase = _Phase.closed;
  Size _from = const Size(40, 40);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _morph.reduceMotion = _reduceMotion;
    _rebuildEntry();
  }

  @override
  void didUpdateWidget(GlassMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildEntry();
  }

  void _rebuildEntry() {
    final entry = _entry;
    if (entry == null) return;
    // Not during a build of our own: the overlay may be building too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry == entry && entry.mounted) entry.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _morph.dispose();
    _triggerFocus.dispose();
    super.dispose();
  }

  void _onMorph() {
    if (_phase == _Phase.leaving && _morph.value == 0) _remove();
  }

  void _open() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _from = box.size;
    setState(() => _phase = _Phase.open);
    if (_entry == null) {
      _entry = OverlayEntry(builder: (context) => _MenuOverlay(menu: this));
      Overlay.of(context).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
    _morph
      ..tune(600, 46)
      ..set(1);
  }

  void _close({bool restoreFocus = true}) {
    if (_phase != _Phase.open) return;
    setState(() => _phase = _Phase.leaving);
    _entry?.markNeedsBuild();
    if (restoreFocus) _triggerFocus.requestFocus();
    _morph
      ..tune(900, 57)
      ..set(0);
    if (_morph.value == 0) _remove();
  }

  void _remove() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    if (mounted) setState(() => _phase = _Phase.closed);
  }

  @override
  Widget build(BuildContext context) {
    final open = _phase == _Phase.open;
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        expanded: open,
        child: AnimatedBuilder(
          animation: _morph,
          builder: (context, child) {
            final t = _unit(_morph.value);
            return Opacity(opacity: t == 0 ? 1 : 1 - _unit(t / 0.2), child: child);
          },
          child: GlassButton(
            key: _triggerKey,
            focusNode: _triggerFocus,
            icon: widget.icon ?? const GlassEllipsis(),
            semanticLabel: widget.semanticLabel,
            onPressed: () => open ? _close() : _open(),
          ),
        ),
      ),
    );
  }
}

/// The ellipsis a [GlassMenu]'s trigger shows by default: three dots.
class GlassEllipsis extends StatelessWidget {
  /// Creates an ellipsis, [size] logical pixels across.
  const GlassEllipsis({super.key, this.size, this.color});

  /// Its width and height, in logical pixels. Defaults to the ambient icon size, or 20.
  final double? size;

  /// Its colour. Defaults to the ambient icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final side = size ?? icon.size ?? 20;
    return CustomPaint(
      size: Size.square(side),
      painter: _EllipsisPainter(color ?? icon.color ?? const Color(0xFF000000)),
    );
  }
}

class _EllipsisPainter extends CustomPainter {
  _EllipsisPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // As Glisse's 16px glyph: dots of radius 1.4 at 3, 8 and 13.
    final unit = size.width / 16;
    final paint = Paint()..color = color;
    for (final x in const [3.0, 8.0, 13.0]) {
      canvas.drawCircle(Offset(x * unit, size.height / 2), 1.4 * unit, paint);
    }
  }

  @override
  bool shouldRepaint(_EllipsisPainter oldDelegate) => oldDelegate.color != color;
}

const double _cardWidth = 200;
const double _cardRadius = 20;

double _resistance(double value) => value.sign * 7 * (1 - math.exp((-value.abs() * 0.12) / 7));

class _MenuOverlay extends StatefulWidget {
  const _MenuOverlay({required this.menu});

  final _GlassMenuState menu;

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> with TickerProviderStateMixin {
  late final GlassSpring _scale = GlassSpring(vsync: this, value: 1, stiffness: 650, damping: 36);
  late final GlassSpring _x = GlassSpring(vsync: this, stiffness: 600, damping: 30);
  late final GlassSpring _y = GlassSpring(vsync: this, stiffness: 600, damping: 30);
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _plateHost = GlobalKey();
  final Map<int, GlobalKey> _rowKeys = {};
  final Map<int, FocusNode> _focusNodes = {};

  int? _gesture;
  Offset _gestureStart = Offset.zero;
  bool _pressed = false;
  int? _current;
  Rect _plate = Rect.zero;
  bool _plateShown = false;
  bool _plateInstant = true;
  int? _focusVisible;

  _GlassMenuState get _menu => widget.menu;

  @override
  void initState() {
    super.initState();
    for (final spring in [_scale, _x, _y]) {
      spring.reduceMotion = _menu._reduceMotion;
    }
    // As on iOS, the first row takes focus as the menu opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = _enabledRows().firstOrNull;
      if (first != null) _focusNodes[first]?.requestFocus();
    });
  }

  @override
  void dispose() {
    _scale.dispose();
    _x.dispose();
    _y.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<GlassMenuEntry> get _items => _menu.widget.items;

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
      _focusNodes.putIfAbsent(index, () => FocusNode(debugLabel: 'GlassMenu row $index'));

  int? _rowAt(Offset global) {
    for (final index in _enabledRows()) {
      final box = _rowKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final local = box.globalToLocal(global);
      if ((Offset.zero & box.size).contains(local)) return index;
    }
    return null;
  }

  Rect? _rowRect(int index) {
    final box = _rowKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
    final host = _plateHost.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || host == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero, ancestor: host);
    return origin & box.size;
  }

  // The plate slides between rows for a drag and for a hovering mouse alike.
  void _highlight(int? index) {
    if (_current == index) return;
    final first = _current == null;
    _current = index;
    if (index == null) {
      setState(() => _plateShown = false);
      return;
    }
    final rect = _rowRect(index);
    if (rect == null) return;
    setState(() {
      // The first row lights up in place and at once; later rows slide to it.
      _plateInstant = first;
      _plate = rect;
      _plateShown = true;
    });
  }

  void _select(int index) {
    final item = _items[index];
    if (item is! GlassMenuItem || !item.enabled) return;
    _menu._close();
    item.onSelected?.call();
  }

  Size get _cardSize {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size : const Size(_cardWidth, 200);
  }

  void _down(PointerDownEvent event) {
    if (_gesture != null) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    _gesture = event.pointer;
    _gestureStart = event.position;
    final size = _cardSize;
    setState(() => _pressed = true);
    _scale.set(1 + 5 / math.max(math.max(size.width, size.height), 200));
    _highlight(_rowAt(event.position));
  }

  void _move(PointerEvent event) {
    if (_gesture == null) {
      // Crossing a separator keeps the plate on the last row, so it slides
      // across the gap to the next one.
      if (event.kind == PointerDeviceKind.mouse) {
        final row = _rowAt(event.position);
        if (row != null) _highlight(row);
      }
      return;
    }
    if (event.pointer != _gesture) return;
    _highlight(_rowAt(event.position));
    final delta = event.position - _gestureStart;
    _x.set(_resistance(delta.dx), instant: true);
    _y.set(_resistance(delta.dy), instant: true);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _gesture) return;
    final chosen = event is PointerUpEvent ? _rowAt(event.position) : null;
    _highlight(null);
    _gesture = null;
    setState(() => _pressed = false);
    _scale.set(1);
    _x.set(0);
    _y.set(0);
    if (chosen != null) _select(chosen);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _menu._close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _menu._close(restoreFocus: false);
      return KeyEventResult.ignored;
    }
    final moves = {
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
    };
    if (!moves.contains(key)) return KeyEventResult.ignored;
    if (_gesture == null) _highlight(null);
    final rows = _enabledRows();
    if (rows.isEmpty) return KeyEventResult.handled;
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
    _focusNodes[rows[next]]?.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    final theme = GlassTheme.of(menu.context);
    final trailing = menu.widget.align == GlassMenuAlign.end;
    final leaving = menu._phase == _Phase.leaving;
    final anchor = trailing ? Alignment.topRight : Alignment.topLeft;

    Widget card = AnimatedBuilder(
      animation: Listenable.merge([menu._morph, _scale, _x, _y]),
      builder: (context, _) => _buildCard(theme, trailing, leaving),
    );
    if (menu._reduceMotion) {
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(opacity: value, child: child),
        child: card,
      );
    }

    return GlassTheme(
      data: theme,
      child: Stack(
        children: [
          // A press anywhere else closes the menu, and still reaches what's there.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => menu._close(restoreFocus: false),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: menu._link,
              showWhenUnlinked: false,
              targetAnchor: anchor,
              followerAnchor: anchor,
              child: IgnorePointer(
                ignoring: leaving,
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: menu.widget.semanticLabel,
                  child: Focus(onKeyEvent: _key, child: card),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(GlassThemeData theme, bool trailing, bool leaving) {
    final menu = _menu;
    final from = menu._from;
    final t = _unit(menu._morph.value);
    final settled = t == 1;
    final scale = 0.5 + 0.5 * t;
    final origin = Offset(trailing ? _cardWidth - from.width / 2 : from.width / 2, from.height / 2);
    final contentOpacity = leaving ? _unit((t - 0.55) / 0.45) : _unit((t - 0.15) / 0.6);
    final blur = 6 * (1 - t);

    Widget content = _buildContent(theme);
    content = ImageFiltered(
      enabled: !settled && blur > 0.01,
      imageFilter: ui.ImageFilter.blur(sigmaX: math.max(blur, 0.01), sigmaY: math.max(blur, 0.01)),
      child: content,
    );
    content = ClipPath(
      clipBehavior: settled ? Clip.none : Clip.antiAlias,
      clipper: _ContentClip(t: t, from: from, trailing: trailing, origin: origin, scale: scale),
      child: content,
    );
    content = Transform(
      transform: settled ? Matrix4.identity() : _scaleAbout(origin, scale),
      child: content,
    );
    content = Opacity(opacity: contentOpacity, child: content);

    Widget card = SizedBox(
      key: _cardKey,
      width: _cardWidth,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: _Surface(t: t, from: from, trailing: trailing, theme: theme)),
          Positioned.fill(
            child: IgnorePointer(
              child: Flow(
                delegate: _GlyphFlow(t: t, from: from, trailing: trailing, origin: origin),
                children: [
                  ImageFiltered(
                    enabled: 8 * t > 0.01,
                    imageFilter: ui.ImageFilter.blur(sigmaX: math.max(8 * t, 0.01), sigmaY: math.max(8 * t, 0.01)),
                    child: SizedBox.fromSize(
                      size: from,
                      child: Center(
                        child: IconTheme.merge(
                          data: IconThemeData(color: theme.foreground, size: 20),
                          child: menu.widget.icon ?? const GlassEllipsis(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _pressed ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(_cardRadius)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.fromRGBO(255, 255, 255, 0.11), Color.fromRGBO(255, 255, 255, 0.025)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Held, the card swells about its trigger's corner and gives a little
    // towards the finger.
    final pivot = Offset(trailing ? _cardWidth - 20 : 20, 20);
    card = Transform(
      transform: Matrix4.translationValues(_x.value, _y.value, 0)..multiply(_scaleAbout(pivot, _scale.value)),
      child: card,
    );

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerHover: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: MouseRegion(
        onExit: (event) {
          if (_gesture == null) _highlight(null);
        },
        child: card,
      ),
    );
  }

  Widget _buildContent(GlassThemeData theme) {
    final children = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      switch (item) {
        case GlassMenuSeparator():
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
            child: SizedBox(height: hairline(context), child: ColoredBox(color: theme.separator)),
          ));
        case GlassMenuItem():
          children.add(_row(theme, i, item));
      }
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Stack(
        key: _plateHost,
        children: [
          // As Glisse's plate: it slides to each row, taking the row's size
          // at once.
          Positioned(
            left: 0,
            top: 0,
            width: _plate.width,
            height: _plate.height,
            child: TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(end: _plate.topLeft),
              duration: _plateInstant || _menu._reduceMotion ? Duration.zero : const Duration(milliseconds: 100),
              curve: const Cubic(0.2, 0.8, 0.2, 1),
              builder: (context, at, child) => Transform.translate(offset: at, child: child),
              child: AnimatedOpacity(
                opacity: _plateShown ? 1 : 0,
                duration: _plateInstant && _plateShown ? Duration.zero : const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.highlight,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _row(GlassThemeData theme, int index, GlassMenuItem item) {
    final colour = item.destructive ? theme.destructive : theme.foreground;
    final scrubbing = _current != null;
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
    // The overlay sits outside the page's text style: take the menu's own.
    final inherited = DefaultTextStyle.of(_menu.context).style;
    row = DefaultTextStyle(
      style: inherited.merge(theme.textStyle).copyWith(color: colour, fontSize: 14, decoration: TextDecoration.none),
      child: row,
    );
    row = DecoratedBox(
      decoration: BoxDecoration(
        color: _focusVisible == index && !scrubbing ? theme.highlight : const Color(0x00000000),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: row,
    );
    return Semantics(
      key: _rowKey(index),
      button: true,
      enabled: item.enabled,
      onTap: item.enabled ? () => _select(index) : null,
      child: FocusableActionDetector(
        focusNode: _focusNode(index),
        enabled: item.enabled,
        mouseCursor: item.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (shown) {
          setState(() {
            if (shown) {
              _focusVisible = index;
            } else if (_focusVisible == index) {
              _focusVisible = null;
            }
          });
        },
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

Matrix4 _scaleAbout(Offset origin, double scale) => Matrix4.translationValues(origin.dx, origin.dy, 0)
  ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
  ..multiply(Matrix4.translationValues(-origin.dx, -origin.dy, 0));

/// The glass's rect as it grows from the trigger's size to the card's,
/// anchored at the trigger's corner.
Rect _surfaceRect(Size card, Size from, double t, bool trailing) {
  final width = from.width + (card.width - from.width) * t;
  final height = from.height + (card.height - from.height) * t;
  return Rect.fromLTWH(trailing ? card.width - width : 0, 0, width, height);
}

class _Surface extends StatelessWidget {
  const _Surface({required this.t, required this.from, required this.trailing, required this.theme});

  final double t;
  final Size from;
  final bool trailing;
  final GlassThemeData theme;

  @override
  Widget build(BuildContext context) {
    final opacity = _unit(t / 0.2);
    if (opacity <= 0) return const SizedBox.expand();
    // The surface fades in with its blur: a filter can't be faded, so its
    // strength grows instead.
    return IgnorePointer(
      child: CustomPaint(
        painter: _SurfaceShadow(t: t, from: from, trailing: trailing, color: theme.shadow, opacity: opacity),
        child: ClipRRect(
          clipper: _SurfaceClip(t: t, from: from, trailing: trailing),
          child: BackdropFilter(
            filter: frostFilter(sigma: 22 * opacity, saturation: 1 + 0.9 * opacity),
            child: CustomPaint(
              size: Size.infinite,
              painter: _SurfaceFill(
                t: t,
                from: from,
                trailing: trailing,
                fill: theme.surface,
                edge: theme.surfaceEdge,
                opacity: opacity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceClip extends CustomClipper<RRect> {
  _SurfaceClip({required this.t, required this.from, required this.trailing});

  final double t;
  final Size from;
  final bool trailing;

  @override
  RRect getClip(Size size) => roundedRect(_surfaceRect(size, from, t, trailing), _cardRadius);

  @override
  bool shouldReclip(_SurfaceClip oldClipper) =>
      oldClipper.t != t || oldClipper.from != from || oldClipper.trailing != trailing;
}

class _SurfaceShadow extends CustomPainter {
  _SurfaceShadow({
    required this.t,
    required this.from,
    required this.trailing,
    required this.color,
    required this.opacity,
  });

  final double t;
  final Size from;
  final bool trailing;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = roundedRect(_surfaceRect(size, from, t, trailing), _cardRadius);
    paintDropShadow(
      canvas,
      rrect,
      color: color.withValues(alpha: color.a * opacity),
      offset: const Offset(0, 12),
      blur: 40,
    );
  }

  @override
  bool shouldRepaint(_SurfaceShadow oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.from != from ||
      oldDelegate.trailing != trailing ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}

class _SurfaceFill extends CustomPainter {
  _SurfaceFill({
    required this.t,
    required this.from,
    required this.trailing,
    required this.fill,
    required this.edge,
    required this.opacity,
  });

  final double t;
  final Size from;
  final bool trailing;
  final Color fill;
  final Color edge;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = roundedRect(_surfaceRect(size, from, t, trailing), _cardRadius);
    canvas.drawRRect(rrect, Paint()..color = fill.withValues(alpha: fill.a * opacity));
    paintInsetShadow(canvas, rrect, color: edge.withValues(alpha: edge.a * opacity), spread: 0.5);
  }

  @override
  bool shouldRepaint(_SurfaceFill oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.from != from ||
      oldDelegate.trailing != trailing ||
      oldDelegate.fill != fill ||
      oldDelegate.edge != edge ||
      oldDelegate.opacity != opacity;
}

/// The rows stay inside the glass: clipped to its rect, mapped back through
/// their own scale.
class _ContentClip extends CustomClipper<Path> {
  _ContentClip({
    required this.t,
    required this.from,
    required this.trailing,
    required this.origin,
    required this.scale,
  });

  final double t;
  final Size from;
  final bool trailing;
  final Offset origin;
  final double scale;

  @override
  Path getClip(Size size) {
    final surface = _surfaceRect(size, from, t, trailing);
    double local(double edge, double centre) => centre + (edge - centre) / scale;
    final rect = Rect.fromLTRB(
      local(surface.left, origin.dx),
      local(surface.top, origin.dy),
      local(surface.right, origin.dx),
      local(surface.bottom, origin.dy),
    );
    return Path()..addRRect(roundedRect(rect, _cardRadius / scale));
  }

  @override
  bool shouldReclip(_ContentClip oldClipper) =>
      oldClipper.t != t ||
      oldClipper.from != from ||
      oldClipper.trailing != trailing ||
      oldClipper.origin != origin ||
      oldClipper.scale != scale;
}

/// The trigger's icon rides the glass towards its centre, swelling and
/// blurring away as the rows arrive.
class _GlyphFlow extends FlowDelegate {
  _GlyphFlow({required this.t, required this.from, required this.trailing, required this.origin});

  final double t;
  final Size from;
  final bool trailing;
  final Offset origin;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) => BoxConstraints.tight(from);

  @override
  void paintChildren(FlowPaintingContext context) {
    final size = context.size;
    final opacity = 1 - _unit(t / 0.45);
    if (opacity <= 0) return;
    final width = from.width + (size.width - from.width) * t;
    final height = from.height + (size.height - from.height) * t;
    final drift = 0.3 * t;
    final dx = ((trailing ? size.width - width / 2 : width / 2) - origin.dx) * drift;
    final dy = (height / 2 - origin.dy) * drift;
    final left = trailing ? size.width - from.width : 0.0;
    final centre = Offset(from.width / 2, from.height / 2);
    final transform = Matrix4.translationValues(left + dx, dy, 0)..multiply(_scaleAbout(centre, 1 + 0.6 * t));
    context.paintChild(0, transform: transform, opacity: opacity);
  }

  @override
  bool shouldRepaint(_GlyphFlow oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.from != from ||
      oldDelegate.trailing != trailing ||
      oldDelegate.origin != origin;
}

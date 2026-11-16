import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';
import 'overlay_scope.dart';

/// Opens and closes a [GlassPopover] from outside it.
class GlassPopoverController extends ChangeNotifier {
  bool _open = false;

  bool get isOpen => _open;

  void show() => _set(true);

  void hide() => _set(false);

  void toggle() => _set(!_open);

  void _set(bool open) {
    if (open == _open) return;
    _open = open;
    notifyListeners();
  }
}

/// Which side of the anchor a [GlassPopover] prefers.
enum GlassPopoverDirection { below, above }

/// A card of glass that springs out of its anchor, below it or above it when
/// there's no room, and closes on a tap anywhere else or on Escape.
class GlassPopover extends StatefulWidget {
  const GlassPopover({
    super.key,
    required this.child,
    required this.popoverBuilder,
    this.controller,
    this.tapToToggle = true,
    this.direction = GlassPopoverDirection.below,
    this.alignment = Alignment.center,
    this.gap = 8,
    this.width,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.onOpenChanged,
  });

  /// The anchor.
  final Widget child;
  final WidgetBuilder popoverBuilder;

  /// Opens and closes it; without one, a tap on the anchor does.
  final GlassPopoverController? controller;

  /// Whether a tap on the anchor opens and closes it.
  final bool tapToToggle;
  final GlassPopoverDirection direction;

  /// Where along the anchor the card lines up: its left edge ([Alignment.centerLeft]),
  /// its middle, or its right edge.
  final Alignment alignment;

  /// The space between the anchor and the card.
  final double gap;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double radius;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<GlassPopover> createState() => _GlassPopoverState();
}

class _GlassPopoverState extends State<GlassPopover> with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final Object _group = Object();
  GlassPopoverController? _own;
  GlassPopoverController get _controller => widget.controller ?? (_own ??= GlassPopoverController());

  late final GlassSpring _open = GlassSpring(vsync: this, stiffness: 600, damping: 46);
  OverlayEntry? _entry;
  bool _above = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _open.addListener(_settled);
  }

  @override
  void didUpdateWidget(GlassPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
      _changed();
    }
    _entry?.markNeedsBuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _open.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    _removeEntry();
    _open.dispose();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.isOpen) {
      _show();
    } else {
      _open
        ..tune(900, 57)
        ..set(0);
      _settled();
    }
    widget.onOpenChanged?.call(_controller.isOpen);
  }

  void _settled() {
    if (!_controller.isOpen && _open.value <= 0.001 && !_open.isMoving) _removeEntry();
  }

  void _show() {
    _above = widget.direction == GlassPopoverDirection.above;
    final box = context.findRenderObject() as RenderBox?;
    final screen = MediaQuery.maybeSizeOf(context);
    if (box != null && box.hasSize && screen != null) {
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      // Too near the bottom for the card, it opens upwards, and the other way round.
      if (!_above && screen.height - bottom < 220 && top > screen.height - bottom) _above = true;
      if (_above && top < 220 && screen.height - bottom > top) _above = false;
    }
    if (_entry == null) {
      final carried = GlassOverlayContext.of(context);
      _entry = OverlayEntry(builder: (context) => carried.wrap(_card()));
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    }
    _open
      ..tune(600, 46)
      ..set(1);
  }

  Widget _card() {
    final theme = GlassTheme.of(context);
    final x = widget.alignment.x;
    final anchor = Alignment(x, _above ? -1 : 1);
    final follower = Alignment(x, _above ? 1 : -1);
    Widget card = Glass(
      borderRadius: widget.radius,
      tint: floatingTint(theme),
      blur: 5,
      padding: widget.padding,
      child: Builder(builder: widget.popoverBuilder),
    );
    if (widget.width != null) card = SizedBox(width: widget.width, child: card);
    card = GlassSurfaceShadow(radius: widget.radius, child: card);
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: anchor,
        followerAnchor: follower,
        offset: Offset(0, _above ? -widget.gap : widget.gap),
        child: TapRegion(
          groupId: _group,
          onTapOutside: (_) => _controller.hide(),
          child: Shortcuts(
            shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
                  _controller.hide();
                  return null;
                }),
              },
              child: Focus(
                autofocus: true,
                child: AnimatedBuilder(
                  animation: _open,
                  child: card,
                  builder: (context, child) {
                    final t = _open.value;
                    return IgnorePointer(
                      ignoring: !_controller.isOpen,
                      child: Opacity(
                        opacity: (t / 0.3).clamp(0.0, 1.0),
                        child: Transform.scale(
                          alignment: follower,
                          scale: 0.6 + 0.4 * t,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget anchor = widget.child;
    if (widget.tapToToggle) {
      anchor = GestureDetector(behavior: HitTestBehavior.opaque, onTap: _controller.toggle, child: anchor);
    }
    return CompositedTransformTarget(
      link: _link,
      child: TapRegion(groupId: _group, child: anchor),
    );
  }
}

/// A small label of glass over its child, shown while a mouse rests on it or
/// a finger presses it long.
class GlassTooltip extends StatefulWidget {
  const GlassTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 500),
    this.showDuration = const Duration(milliseconds: 1500),
  });

  final String message;
  final Widget child;

  /// How long a mouse rests before it shows.
  final Duration waitDuration;

  /// How long it stays after a long press ends.
  final Duration showDuration;

  @override
  State<GlassTooltip> createState() => _GlassTooltipState();
}

class _GlassTooltipState extends State<GlassTooltip> with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  late final GlassSpring _shown = GlassSpring(vsync: this, stiffness: 700, damping: 50);
  OverlayEntry? _entry;
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _shown.addListener(() {
      if (!_visible && _shown.value <= 0.001 && !_shown.isMoving) _remove();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remove();
    _shown.dispose();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _show() {
    _timer?.cancel();
    _visible = true;
    if (_entry == null) {
      final carried = GlassOverlayContext.of(context);
      _entry = OverlayEntry(builder: (context) => carried.wrap(_label()));
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    }
    _shown.set(1);
  }

  void _hide() {
    _timer?.cancel();
    _visible = false;
    _shown.set(0);
    if (_shown.value <= 0.001) _remove();
  }

  Widget _label() {
    final theme = GlassTheme.of(context);
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -6),
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _shown,
            builder: (context, child) => Opacity(
              opacity: _shown.value.clamp(0.0, 1.0),
              child:
                  Transform.scale(alignment: Alignment.bottomCenter, scale: 0.85 + 0.15 * _shown.value, child: child),
            ),
            child: Glass(
              borderRadius: double.infinity,
              tint: floatingTint(theme),
              blur: 4,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(widget.message, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        tooltip: widget.message,
        child: MouseRegion(
          onEnter: (event) {
            if (event.kind != PointerDeviceKind.mouse) return;
            _timer?.cancel();
            _timer = Timer(widget.waitDuration, _show);
          },
          onExit: (_) => _hide(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: _show,
            onLongPressEnd: (_) {
              _timer?.cancel();
              _timer = Timer(widget.showDuration, _hide);
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

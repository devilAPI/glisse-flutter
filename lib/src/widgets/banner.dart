import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';
import 'overlay_scope.dart';

/// A banner shown by [showGlassBanner], to dismiss it early.
class GlassBannerController {
  GlassBannerController._();

  _GlassBannerState? _state;
  final Completer<void> _closed = Completer<void>();

  /// Completes once the banner has gone.
  Future<void> get closed => _closed.future;

  /// Whether it's still on screen, or on its way off.
  bool get isShowing => !_closed.isCompleted;

  /// Sends it back up and away.
  void dismiss() {
    final state = _state;
    if (state == null) {
      // Not built yet: it leaves as soon as it is.
      _dismissed = true;
    } else {
      state._dismiss();
    }
  }

  bool _dismissed = false;

  void _finish() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

GlassBannerController? _current;

/// Shows a card of glass that drops in from the top of the screen, as iOS's
/// notifications do: a [leading] icon beside a [title] over a [message].
///
/// It goes again after [duration], when swiped up, or when tapped, which
/// also calls [onTap]. A new banner replaces one already showing.
GlassBannerController showGlassBanner({
  required BuildContext context,
  required Widget title,
  Widget? message,
  Widget? leading,
  Widget? trailing,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onTap,
}) {
  _current?.dismiss();
  final controller = GlassBannerController._();
  _current = controller;
  final carried = GlassOverlayContext.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var removed = false;
  void gone() {
    if (removed) return;
    removed = true;
    if (entry.mounted) entry.remove();
    entry.dispose();
    if (identical(_current, controller)) _current = null;
    controller._finish();
  }

  entry = OverlayEntry(
    builder:
        (context) => carried.wrap(
          _GlassBanner(
            controller: controller,
            title: title,
            message: message,
            leading: leading,
            trailing: trailing,
            duration: duration,
            onTap: onTap,
            onGone: gone,
          ),
        ),
  );
  overlay.insert(entry);
  return controller;
}

class _GlassBanner extends StatefulWidget {
  const _GlassBanner({
    required this.controller,
    required this.title,
    required this.message,
    required this.leading,
    required this.trailing,
    required this.duration,
    required this.onTap,
    required this.onGone,
  });

  final GlassBannerController controller;
  final Widget title;
  final Widget? message;
  final Widget? leading;
  final Widget? trailing;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onGone;

  @override
  State<_GlassBanner> createState() => _GlassBannerState();
}

class _GlassBannerState extends State<_GlassBanner> with TickerProviderStateMixin {
  // 0 is tucked away above the screen, 1 in place.
  late final GlassSpring _shown = GlassSpring(vsync: this, stiffness: 320, damping: 25);
  late final GlassSpring _drag = GlassSpring(vsync: this, stiffness: 500, damping: 40);
  Timer? _timer;
  double _dragged = 0;
  bool _leaving = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _shown.addListener(_check);
    _timer = Timer(widget.duration, _dismiss);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.controller._dismissed) {
        _dismiss();
      } else if (!_leaving) {
        _shown.set(1);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shown.reduceMotion = reduce;
    _drag.reduceMotion = reduce;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (identical(widget.controller._state, this)) widget.controller._state = null;
    _shown.dispose();
    _drag.dispose();
    // Taken down with the overlay before it could leave: it's gone all the same.
    if (!_gone) {
      _gone = true;
      if (identical(_current, widget.controller)) _current = null;
      widget.controller._finish();
    }
    super.dispose();
  }

  void _check() {
    if (_leaving && !_gone && _shown.value <= 0.001 && !_shown.isMoving) {
      _gone = true;
      widget.onGone();
    }
  }

  void _dismiss() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    setState(() {});
    _shown
      ..tune(500, 45)
      ..set(0);
    _check();
  }

  void _update(DragUpdateDetails details) {
    if (_leaving) return;
    _timer?.cancel();
    _dragged += details.delta.dy;
    // Up it follows the finger; down it gives a little and no more.
    final offset = _dragged <= 0 ? _dragged : 16 * (1 - math.exp(-_dragged / 60));
    _drag.set(offset, instant: true);
  }

  void _end(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250 || _dragged < -30) {
      // Thrown up, it keeps going from where the finger left it.
      _dismiss();
      return;
    }
    _drag.set(0);
    _dragged = 0;
    _timer = Timer(widget.duration, _dismiss);
  }

  void _tap() {
    if (_leaving) return;
    widget.onTap?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final top = MediaQuery.paddingOf(context).top;
    final padding = MediaQuery.paddingOf(context);

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: widget.title,
        ),
        if (widget.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DefaultTextStyle(
              style: base.copyWith(
                fontSize: 14,
                height: 1.3,
                color: theme.foreground.withValues(alpha: theme.foreground.a * 0.8),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              child: widget.message!,
            ),
          ),
      ],
    );

    final card = GlassSurfaceShadow(
      radius: 26,
      offset: const Offset(0, 8),
      blur: 30,
      child: Glass(
        borderRadius: 26,
        tint: floatingTint(theme),
        blur: 5,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: theme.foreground, size: 26),
                child: SizedBox.square(dimension: 38, child: Center(child: widget.leading)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: text),
            if (widget.trailing != null) ...[
              const SizedBox(width: 10),
              DefaultTextStyle(
                style: base.copyWith(fontSize: 13, color: theme.muted),
                child: IconTheme.merge(data: IconThemeData(color: theme.muted, size: 18), child: widget.trailing!),
              ),
            ],
          ],
        ),
      ),
    );

    final banner = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      child: card,
    );

    return Positioned(
      left: 8 + padding.left,
      right: 8 + padding.right,
      top: top + 8,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: IgnorePointer(
            ignoring: _leaving,
            child: Semantics(
              liveRegion: true,
              container: true,
              button: widget.onTap != null,
              onTap: widget.onTap != null ? _tap : null,
              onDismiss: _dismiss,
              child: AnimatedBuilder(
                animation: Listenable.merge([_shown, _drag]),
                child: banner,
                builder: (context, child) {
                  final shown = _shown.value;
                  // Tucked away, it waits above the safe area, out of sight.
                  return Opacity(
                    opacity: _unit(shown * 1.5),
                    child: Transform.translate(
                      offset: Offset(0, _drag.value - (1 - shown) * (top + 8)),
                      child: FractionalTranslation(
                        translation: Offset(0, -(1 - shown) * 1.1),
                        child: Transform.scale(scale: 0.94 + 0.06 * _unit(shown), child: child),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

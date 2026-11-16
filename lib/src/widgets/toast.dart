import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';
import 'overlay_scope.dart';

/// A toast shown by [showGlassToast], to dismiss it early.
class GlassToastController {
  GlassToastController._();

  _GlassToastState? _state;
  final Completer<void> _closed = Completer<void>();

  /// Completes once the toast has gone.
  Future<void> get closed => _closed.future;

  /// Whether it's still on screen, or on its way off.
  bool get isShowing => !_closed.isCompleted;

  /// Sends it back up and away.
  void dismiss() => _state?._dismiss();

  void _finish() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

GlassToastController? _current;

/// Shows a capsule of glass that springs down from the top of the screen,
/// as iOS's banners do, and goes again after [duration] or when swiped up.
///
/// A new toast replaces one already showing.
GlassToastController showGlassToast(
  BuildContext context, {
  required Widget message,
  Widget? icon,
  Duration duration = const Duration(seconds: 3),
  VoidCallback? onTap,
}) {
  _current?.dismiss();
  final controller = GlassToastController._();
  _current = controller;
  final carried = GlassOverlayContext.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => carried.wrap(
      _GlassToast(
        controller: controller,
        message: message,
        icon: icon,
        duration: duration,
        onTap: onTap,
        onGone: () {
          entry.remove();
          entry.dispose();
          if (identical(_current, controller)) _current = null;
          controller._finish();
        },
      ),
    ),
  );
  overlay.insert(entry);
  return controller;
}

class _GlassToast extends StatefulWidget {
  const _GlassToast({
    required this.controller,
    required this.message,
    required this.icon,
    required this.duration,
    required this.onTap,
    required this.onGone,
  });

  final GlassToastController controller;
  final Widget message;
  final Widget? icon;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onGone;

  @override
  State<_GlassToast> createState() => _GlassToastState();
}

class _GlassToastState extends State<_GlassToast> with TickerProviderStateMixin {
  // 0 is tucked away above the screen, 1 in place.
  late final GlassSpring _shown = GlassSpring(vsync: this, stiffness: 380, damping: 26);
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
      if (mounted && !_leaving) _shown.set(1);
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
    _shown
      ..tune(500, 45)
      ..set(0);
    if (_shown.value == 0) _check();
  }

  void _update(DragUpdateDetails details) {
    if (_leaving) return;
    _timer?.cancel();
    _dragged += details.delta.dy;
    // Up it follows the finger; down it gives a little and no more.
    final shown = _dragged <= 0 ? _dragged : 14 * (1 - math.exp(-_dragged / 50));
    _drag.set(shown, instant: true);
  }

  void _end(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250 || _dragged < -24) {
      _dismiss();
      return;
    }
    _drag.set(0);
    _dragged = 0;
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final toast = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null
          ? null
          : () {
              widget.onTap!();
              _dismiss();
            },
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      child: GlassSurfaceShadow(
        radius: double.infinity,
        offset: const Offset(0, 6),
        blur: 24,
        child: Glass(
          borderRadius: double.infinity,
          tint: floatingTint(theme),
          blur: 4,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 10)],
              Flexible(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: widget.message,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Positioned(
      left: 16,
      right: 16,
      top: top + 8,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: AnimatedBuilder(
              animation: Listenable.merge([_shown, _drag]),
              child: toast,
              builder: (context, child) {
                final shown = _shown.value;
                return Opacity(
                  opacity: shown.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _drag.value),
                    child: FractionalTranslation(
                      translation: Offset(0, -(1 - shown) * 1.6),
                      child: Transform.scale(scale: 0.9 + 0.1 * shown, child: child),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

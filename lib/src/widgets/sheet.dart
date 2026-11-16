import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';
import 'overlay_scope.dart';

/// Shows a sheet of glass that floats up from the bottom, as iOS 26's: inset
/// from the screen's edges, rounded all round, and dragged down to dismiss.
///
/// Resolves with the value the sheet is popped with.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showHandle = true,
  bool isDismissible = true,
  bool enableDrag = true,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 4, 20, 20),
  bool useRootNavigator = true,
}) {
  final carried = GlassOverlayContext.of(context);
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _GlassSheetRoute<T>(
      carried: carried,
      builder: builder,
      showHandle: showHandle,
      dismissible: isDismissible,
      enableDrag: enableDrag,
      padding: padding,
    ),
  );
}

class _GlassSheetRoute<T> extends PopupRoute<T> {
  _GlassSheetRoute({
    required this.carried,
    required this.builder,
    required this.showHandle,
    required this.dismissible,
    required this.enableDrag,
    required this.padding,
  });

  final GlassOverlayContext carried;
  final WidgetBuilder builder;
  final bool showHandle;
  final bool dismissible;
  final bool enableDrag;
  final EdgeInsetsGeometry padding;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Color? get barrierColor => carried.theme.isDark ? const Color(0x55000000) : const Color(0x26000000);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 550);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return carried.wrap(
      _GlassSheet(
        animation: animation,
        builder: builder,
        showHandle: showHandle,
        enableDrag: enableDrag,
        padding: padding,
      ),
    );
  }
}

class _GlassSheet extends StatefulWidget {
  const _GlassSheet({
    required this.animation,
    required this.builder,
    required this.showHandle,
    required this.enableDrag,
    required this.padding,
  });

  final Animation<double> animation;
  final WidgetBuilder builder;
  final bool showHandle;
  final bool enableDrag;
  final EdgeInsetsGeometry padding;

  @override
  State<_GlassSheet> createState() => _GlassSheetState();
}

class _GlassSheetState extends State<_GlassSheet> with SingleTickerProviderStateMixin {
  static final Curve _rise = GlassSpringCurve(stiffness: 300, dampingRatio: 0.86, duration: 0.55);

  late final GlassSpring _drag = GlassSpring(vsync: this, stiffness: 400, damping: 36);
  double _dragged = 0;
  bool _dismissing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _drag.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  // Pulled up past its place, the sheet gives a little and no more.
  static double _resist(double offset) => offset >= 0 ? offset : -24 * (1 - math.exp(offset / 80));

  void _update(DragUpdateDetails details) {
    if (_dismissing) return;
    _dragged += details.delta.dy;
    _drag.set(_resist(_dragged), instant: true);
  }

  void _end(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    final height = context.size?.height ?? 400;
    if (velocity > 700 || (_dragged > height * 0.3 && velocity > -300)) {
      _dismissing = true;
      Navigator.of(context).pop();
      return;
    }
    _drag.jump(_resist(_dragged), velocity: velocity);
    _drag.set(0);
    _dragged = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final media = MediaQuery.of(context);
    Widget sheet = Glass(
      borderRadius: 34,
      tint: floatingTint(theme),
      blur: 5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHandle)
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 6, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.muted.withValues(alpha: theme.muted.a * 0.6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
          Flexible(child: Padding(padding: widget.padding, child: Builder(builder: widget.builder))),
        ],
      ),
    );
    sheet = GlassSurfaceShadow(radius: 34, offset: const Offset(0, 8), blur: 32, child: sheet);
    if (widget.enableDrag) {
      sheet = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _update,
        onVerticalDragEnd: _end,
        child: sheet,
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(8, media.padding.top + 24, 8, 8 + media.viewPadding.bottom + media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: media.size.height * 0.9),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'Sheet',
            child: AnimatedBuilder(
              animation: Listenable.merge([widget.animation, _drag]),
              child: sheet,
              builder: (context, child) {
                final t = widget.animation.value;
                final closing = widget.animation.status == AnimationStatus.reverse;
                final shown = closing ? Curves.easeIn.transform(t) : _rise.transform(t);
                return Transform.translate(
                  offset: Offset(0, _drag.value),
                  child: FractionalTranslation(translation: Offset(0, (1 - shown) * 1.15), child: child),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

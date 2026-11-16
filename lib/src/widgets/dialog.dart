import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'button.dart';
import 'glass.dart';
import 'overlay_scope.dart';

/// Shows a dialog over a dimmed page: it springs in from a little larger, as
/// iOS's alerts do, and fades away when dismissed.
///
/// Resolves with the value the dialog is popped with.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Dismiss',
  bool useRootNavigator = true,
}) {
  final carried = GlassOverlayContext.of(context);
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _GlassDialogRoute<T>(
      carried: carried,
      builder: builder,
      dismissible: barrierDismissible,
      label: barrierLabel,
    ),
  );
}

class _GlassDialogRoute<T> extends PopupRoute<T> {
  _GlassDialogRoute({
    required this.carried,
    required this.builder,
    required this.dismissible,
    required this.label,
  });

  final GlassOverlayContext carried;
  final WidgetBuilder builder;
  final bool dismissible;
  final String label;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => label;

  @override
  Color? get barrierColor => carried.theme.isDark ? const Color(0x66000000) : const Color(0x33000000);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  static final Curve _spring = GlassSpringCurve(stiffness: 420, dampingRatio: 0.78, duration: 0.45);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return carried.wrap(
      SafeArea(
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Builder(builder: builder)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Opening, it springs in from a little larger; dismissed, it fades
    // where it stands.
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final closing = animation.status == AnimationStatus.reverse;
        final scale = closing ? 1.0 : 1.1 - 0.1 * _spring.transform(t);
        final opacity = closing ? Curves.easeOut.transform(t) : Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      },
    );
  }
}

/// A button at the foot of a [GlassAlertDialog].
class GlassDialogAction {
  const GlassDialogAction({
    required this.child,
    this.onPressed,
    this.isDefault = false,
    this.destructive = false,
    this.dismisses = true,
  });

  final Widget child;

  /// Called when chosen, after the dialog is dismissed if [dismisses].
  final VoidCallback? onPressed;

  /// The action the dialog suggests: filled with the accent colour.
  final bool isDefault;

  /// An action that deletes or can't be undone: red.
  final bool destructive;

  /// Whether choosing it closes the dialog.
  final bool dismisses;
}

/// An alert on glass, as iOS 26's: a rounded pane with a title, a message,
/// and capsule buttons side by side when there are two, stacked otherwise.
class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.width = 290,
  });

  final Widget? title;
  final Widget? content;
  final List<GlassDialogAction> actions;
  final double width;

  Widget _button(BuildContext context, GlassDialogAction action) {
    return SizedBox(
      width: double.infinity,
      child: GlassButton(
        height: 44,
        variant: action.isDefault ? GlassButtonVariant.filled : GlassButtonVariant.glass,
        destructive: action.destructive,
        onPressed: () {
          if (action.dismisses) Navigator.of(context).pop();
          action.onPressed?.call();
        },
        child: action.child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final children = <Widget>[
      if (title != null)
        DefaultTextStyle.merge(
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.foreground, height: 1.25),
          textAlign: TextAlign.center,
          child: title!,
        ),
      if (title != null && content != null) const SizedBox(height: 6),
      if (content != null)
        DefaultTextStyle.merge(
          style: TextStyle(
              fontSize: 14, color: theme.foreground.withValues(alpha: theme.foreground.a * 0.8), height: 1.35),
          textAlign: TextAlign.center,
          child: content!,
        ),
      if (actions.isNotEmpty) const SizedBox(height: 18),
      if (actions.length == 2)
        Row(children: [
          Expanded(child: _button(context, actions[0])),
          const SizedBox(width: 10),
          Expanded(child: _button(context, actions[1])),
        ])
      else
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _button(context, actions[i]),
        ],
    ];
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: GlassSurfaceShadow(
          radius: 28,
          child: Glass(
            borderRadius: 28,
            tint: floatingTint(theme),
            blur: 5,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

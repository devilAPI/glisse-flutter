import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';

/// The theme's glass, tinted [tint] (the theme's frost by default).
GlassStyle themedGlass(GlassThemeData theme, {Color? tint, bool shadow = true}) => GlassStyle(
  tint: tint ?? theme.glass,
  edge: theme.edge,
  drop: shadow ? theme.drop : const Color(0x00000000),
  rimShine: theme.rimShine,
  blur: theme.blur,
  saturation: theme.saturation,
  bend: theme.glassBend,
  dispersion: theme.glassDispersion,
  spec: LensSpec.glass,
);

/// Makes a control take focus and answer space and enter, with a ring while
/// it has keyboard focus.
class GlassFocusable extends StatefulWidget {
  /// Makes [child] focusable and activatable while [enabled].
  const GlassFocusable({
    super.key,
    required this.enabled,
    required this.onActivate,
    required this.radius,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onFocusRing,
  });

  /// Whether the control takes focus and shows a pointer cursor.
  final bool enabled;

  /// Called when space or enter is pressed while the control has focus.
  final VoidCallback? onActivate;

  /// The corner radius of the control, in logical px, which the ring follows.
  final double radius;

  /// The control.
  final Widget child;

  /// The focus node to use; null makes one.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Called when the ring shows or hides, for controls that draw their own.
  final ValueChanged<bool>? onFocusRing;

  @override
  State<GlassFocusable> createState() => _GlassFocusableState();
}

class _GlassFocusableState extends State<GlassFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    Widget child = widget.child;
    if (_focused && widget.onFocusRing == null) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.radius + 2),
            side: BorderSide(color: theme.ring, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
          ),
        ),
        child: child,
      );
    }
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      mouseCursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) {
        setState(() => _focused = value);
        widget.onFocusRing?.call(value);
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: child,
    );
  }
}

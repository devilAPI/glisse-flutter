import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';
import 'pressable.dart';

/// How a [GlassButton] is filled.
enum GlassButtonVariant {
  /// Clear glass.
  glass,

  /// Filled with the accent colour, for the primary action.
  filled,
}

/// A button of Liquid Glass, as iOS 26's: it swells and stretches under a
/// finger and lights up at once when pressed.
///
/// With an [icon] and no [child] it's a circle; give it a [semanticLabel].
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    this.child,
    this.icon,
    required this.onPressed,
    this.variant = GlassButtonVariant.glass,
    this.destructive = false,
    this.tint,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.height = 40,
    this.padding,
    this.mode = GlassMode.auto,
  });

  /// The label.
  final Widget? child;

  /// Shown before the label.
  final Widget? icon;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;

  /// Marks an action that deletes or can't be undone: shorthand for a red [tint].
  final bool destructive;

  /// Tints a glass button's label, or a filled button's fill.
  final Color? tint;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// The button's height; an icon-only button is as wide.
  final double height;

  /// Overrides the padding round the label.
  final EdgeInsetsGeometry? padding;
  final GlassMode mode;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  Color _fill(GlassThemeData theme) {
    final filled = widget.variant == GlassButtonVariant.filled;
    final tint = widget.tint ?? (widget.destructive ? theme.destructive : null);
    if (filled) {
      final base = tint ?? theme.fill;
      if (!_enabled) return base;
      if (_pressed) return Color.lerp(base, const Color(0xFF000000), 0.15)!;
      if (_hovered) return Color.lerp(base, const Color(0xFFFFFFFF), 0.12)!;
      return base;
    }
    if (!_enabled) return theme.glass;
    return _pressed || _hovered ? theme.glassActive : theme.glass;
  }

  Color _ink(GlassThemeData theme) {
    if (widget.variant == GlassButtonVariant.filled) return const Color(0xFFFFFFFF);
    return widget.tint ?? (widget.destructive ? theme.destructive : theme.foreground);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final iconOnly = widget.icon != null && widget.child == null;
    final height = widget.height;
    final radius = height / 2;
    final ink = _ink(theme);
    final padding = widget.padding ??
        (iconOnly ? EdgeInsets.zero : EdgeInsets.only(left: widget.icon != null ? 12 : 16, right: 16));

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) widget.icon!,
        if (widget.icon != null && widget.child != null) const SizedBox(width: 8),
        if (widget.child != null) widget.child!,
      ],
    );
    content = DefaultTextStyle.merge(
      style: theme.textStyle.copyWith(color: ink, fontSize: 14),
      maxLines: 1,
      child: IconTheme.merge(data: IconThemeData(color: ink, size: 20), child: content),
    );

    final fill = _fill(theme);
    Widget button = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: fill),
      // Lights up at once when pressed, as on iOS, and fades on release.
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.ease,
      builder: (context, color, child) => LiquidGlassBox(
        radius: radius,
        style: GlassStyle(
          tint: color ?? fill,
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
        child: child,
      ),
      child: GlassPressableGlow(
        radius: radius,
        enabled: _enabled,
        child: SizedBox(
          height: height,
          width: iconOnly ? height : null,
          child: Padding(padding: padding, child: Center(widthFactor: 1, child: content)),
        ),
      ),
    );

    if (_focused) {
      // A 2px ring 2px outside the edge, as CSS's outline-offset: 2px.
      button = CustomPaint(
        foregroundPainter: _FocusRingPainter(color: theme.ring, radius: radius),
        child: button,
      );
    }

    button = GlassPressable(
      enabled: _enabled,
      onPressChanged: (state) {
        if (state.pressed != _pressed) setState(() => _pressed = state.pressed);
      },
      child: button,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Opacity(opacity: _enabled ? 1 : 0.35, child: button),
        ),
      ),
    );
  }
}

/// Lays [PressGlow] over its child while the nearest [GlassPressable] is pressed.
class GlassPressableGlow extends StatelessWidget {
  const GlassPressableGlow({super.key, required this.radius, required this.child, this.enabled = true});

  final double radius;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return _GlowScope(radius: radius, child: child);
  }
}

class _GlowScope extends StatefulWidget {
  const _GlowScope({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  State<_GlowScope> createState() => _GlowScopeState();
}

class _GlowScopeState extends State<_GlowScope> {
  PressState _state = PressState.idle;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _update(e.localPosition, true),
      onPointerMove: (e) => _update(e.localPosition, true),
      onPointerUp: (e) => _update(e.localPosition, false),
      onPointerCancel: (e) => _update(e.localPosition, false),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(child: PressGlow(state: _state, radius: widget.radius)),
        ],
      ),
    );
  }

  void _update(Offset local, bool pressed) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _state = PressState(pressed: pressed, position: Offset(local.dx / size.width, local.dy / size.height));
    });
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius + 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) => oldDelegate.color != color || oldDelegate.radius != radius;
}

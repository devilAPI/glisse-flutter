import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'button.dart';
import 'control_utils.dart';

/// Several buttons joined into one capsule of glass, as iOS 26's toolbars
/// group them. Each [GlassButtonGroupItem] lights up on its own when pressed.
class GlassButtonGroup extends StatelessWidget {
  const GlassButtonGroup({super.key, required this.children, this.separators = false, this.height = 40});

  /// Usually [GlassButtonGroupItem]s.
  final List<Widget> children;

  /// Whether to draw hairlines between the items.
  final bool separators;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final row = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && separators) {
        row.add(Container(width: 0.5, height: height * 0.5, color: theme.separator));
      }
      row.add(children[i]);
    }
    return _GroupScope(
      height: height,
      child: LiquidGlassBox(
        radius: height / 2,
        style: themedGlass(theme),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: row),
          ),
        ),
      ),
    );
  }
}

class _GroupScope extends InheritedWidget {
  const _GroupScope({required this.height, required super.child});

  final double height;

  @override
  bool updateShouldNotify(_GroupScope oldWidget) => height != oldWidget.height;
}

/// One button in a [GlassButtonGroup]: an icon, or a short label.
class GlassButtonGroupItem extends StatefulWidget {
  const GlassButtonGroupItem({
    super.key,
    this.icon,
    this.label,
    required this.onPressed,
    this.semanticLabel,
    this.selected = false,
    this.tint,
    this.focusNode,
  }) : assert(icon != null || label != null);

  final Widget? icon;
  final Widget? label;

  /// Null disables the item.
  final VoidCallback? onPressed;
  final String? semanticLabel;

  /// Shows the item in the accent, as a toggled tool.
  final bool selected;
  final Color? tint;
  final FocusNode? focusNode;

  @override
  State<GlassButtonGroupItem> createState() => _GlassButtonGroupItemState();
}

class _GlassButtonGroupItemState extends State<GlassButtonGroupItem> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final height = context.dependOnInheritedWidgetOfExactType<_GroupScope>()?.height ?? 40;
    final ink = widget.selected ? (widget.tint ?? theme.fill) : (widget.tint ?? theme.foreground);
    final content = DefaultTextStyle.merge(
      style: theme.textStyle.copyWith(color: ink, fontSize: 14),
      maxLines: 1,
      child: IconTheme.merge(
        data: IconThemeData(color: ink, size: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) widget.icon!,
            if (widget.icon != null && widget.label != null) const SizedBox(width: 6),
            if (widget.label != null) widget.label!,
          ],
        ),
      ),
    );
    final highlight = _pressed
        ? theme.highlight
        : (_hovered && _enabled ? theme.highlight.withValues(alpha: theme.highlight.a * 0.6) : const Color(0x00000000));
    Widget item = AnimatedContainer(
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
      constraints: BoxConstraints(minWidth: height + 4, minHeight: height),
      padding: EdgeInsets.symmetric(horizontal: widget.label != null ? 12 : 0),
      decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(height / 2)),
      alignment: Alignment.center,
      child: content,
    );
    item = GlassPressableGlow(radius: height / 2, enabled: _enabled, child: item);
    item = Listener(
      onPointerDown: (_) {
        if (_enabled) setState(() => _pressed = true);
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onPressed, child: item),
      ),
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GlassFocusable(
        enabled: _enabled,
        onActivate: widget.onPressed,
        radius: height / 2,
        focusNode: widget.focusNode,
        child: Opacity(opacity: _enabled ? 1 : 0.35, child: item),
      ),
    );
  }
}

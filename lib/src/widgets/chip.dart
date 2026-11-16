import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'button.dart';
import 'control_utils.dart';
import 'input.dart' show GlassGlyph;
import 'pressable.dart';

/// A 32px capsule of glass for a filter, tag or choice. Selected, it fills
/// with the accent and its label turns white. With [onDeleted] it shows a
/// cross that removes it.
class GlassChip extends StatefulWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    this.selectedColor,
    this.enabled = true,
    this.focusNode,
  });

  final Widget label;
  final Widget? icon;
  final bool selected;

  /// Called with the new selection when tapped.
  final ValueChanged<bool>? onSelected;

  /// Shows a cross that calls this.
  final VoidCallback? onDeleted;
  final Color? selectedColor;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<GlassChip> createState() => _GlassChipState();
}

class _GlassChipState extends State<GlassChip> {
  static const double _height = 32;
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive => widget.enabled && widget.onSelected != null;

  void _tap() {
    if (_interactive) widget.onSelected!(!widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final selectedColor = widget.selectedColor ?? theme.fill;
    final ink = widget.selected ? const Color(0xFFFFFFFF) : theme.foreground;
    final base = widget.selected ? selectedColor : theme.glass;
    final tint = widget.selected
        ? (_pressed ? Color.lerp(base, const Color(0xFF000000), 0.15)! : base)
        : (_pressed || _hovered ? theme.glassActive : base);

    final children = <Widget>[
      if (widget.icon != null) ...[
        IconTheme.merge(data: IconThemeData(color: ink, size: 16), child: widget.icon!),
        const SizedBox(width: 6),
      ],
      widget.label,
      if (widget.onDeleted != null) ...[
        const SizedBox(width: 4),
        Semantics(
          button: true,
          label: 'Remove',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onDeleted : null,
            child: SizedBox(
              width: 24,
              height: _height,
              child: Center(
                child: GlassGlyph.clear(color: ink.withValues(alpha: ink.a * 0.7), size: 12),
              ),
            ),
          ),
        ),
      ],
    ];

    Widget chip = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
      builder: (context, color, child) => LiquidGlassBox(
        radius: _height / 2,
        style: themedGlass(theme, tint: color ?? tint),
        child: child,
      ),
      child: GlassPressableGlow(
        radius: _height / 2,
        enabled: _interactive,
        child: SizedBox(
          height: _height,
          child: Padding(
            padding: EdgeInsets.only(left: 12, right: widget.onDeleted != null ? 4 : 12),
            child: DefaultTextStyle.merge(
              style: theme.textStyle.copyWith(color: ink, fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
    chip = GlassPressable(
      enabled: _interactive,
      onPressChanged: (state) {
        if (state.pressed != _pressed) setState(() => _pressed = state.pressed);
      },
      child: chip,
    );
    chip = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _interactive ? _tap : null, child: chip),
    );
    return Semantics(
      button: widget.onSelected != null,
      selected: widget.selected,
      enabled: widget.enabled,
      onTap: _interactive ? _tap : null,
      child: GlassFocusable(
        enabled: _interactive,
        onActivate: _tap,
        radius: _height / 2,
        focusNode: widget.focusNode,
        child: Opacity(opacity: widget.enabled ? 1 : 0.35, child: chip),
      ),
    );
  }
}

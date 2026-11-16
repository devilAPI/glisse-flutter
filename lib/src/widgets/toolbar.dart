import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'glass.dart';
import 'pressable.dart';

/// One icon in a [GlassToolbar] or [GlassButtonGroup]: a 44px circle with no
/// glass of its own, lit while pressed, filled while [selected]. The glass
/// around it swells and stretches under the finger, as one piece.
class GlassToolbarItem extends StatefulWidget {
  /// Creates a toolbar item that shows [icon].
  const GlassToolbarItem({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.selected = false,
    this.tint,
    this.size = 44,
  });

  /// The glyph shown, at 22px.
  final Widget icon;

  /// Null disables the item.
  final VoidCallback? onPressed;

  /// Names the control for assistive technology.
  final String? semanticLabel;

  /// Fills the item, as for a toggled tool.
  final bool selected;

  /// The icon's colour; defaults to the theme's foreground, or its accent
  /// when selected.
  final Color? tint;

  /// The item's width and height, in logical pixels.
  final double size;

  @override
  State<GlassToolbarItem> createState() => _GlassToolbarItemState();
}

class _GlassToolbarItemState extends State<GlassToolbarItem> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final ink = widget.tint ?? (widget.selected ? theme.fill : theme.foreground);
    final fill =
        widget.selected
            ? theme.selection
            : _pressed
            ? theme.highlight
            : _hovered
            ? theme.highlight.withValues(alpha: theme.highlight.a * 0.6)
            : const Color(0x00000000);
    Widget item = AnimatedContainer(
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.ease,
      width: widget.size,
      height: widget.size,
      decoration: ShapeDecoration(
        color: fill,
        shape: CircleBorder(
          side:
              _focused
                  ? BorderSide(color: theme.ring, width: 2, strokeAlign: BorderSide.strokeAlignInside)
                  : BorderSide.none,
        ),
      ),
      alignment: Alignment.center,
      child: IconTheme.merge(data: IconThemeData(color: ink, size: 22), child: widget.icon),
    );
    item = Listener(
      onPointerDown: (_) {
        if (_enabled) setState(() => _pressed = true);
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: item,
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Opacity(opacity: _enabled ? 1 : 0.35, child: item),
        ),
      ),
    );
  }
}

/// Room between groups of items in a [GlassToolbar].
class GlassToolbarSpacer extends StatelessWidget {
  /// Creates a gap of [extent] logical pixels.
  const GlassToolbarSpacer({super.key, this.extent = 12});

  /// The gap's width and height, in logical pixels.
  final double extent;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: extent);
}

/// A floating capsule of glass holding tools, as iOS 26's bottom toolbars:
/// [GlassToolbarItem]s inset 4px from its rim. Pressed anywhere, the whole
/// capsule swells and stretches towards the finger, as a [GlassButton] does.
///
/// Given a bounded width, a `Spacer` among the children pushes them apart.
class GlassToolbar extends StatelessWidget {
  /// Creates a toolbar of [children].
  const GlassToolbar({
    super.key,
    required this.children,
    this.direction = Axis.horizontal,
    this.spacing = 0,
    this.padding = 4,
  });

  /// The items, in order.
  final List<Widget> children;

  /// The axis the children run along.
  final Axis direction;

  /// The inset of the items from the glass's rim.
  final double padding;

  /// Room between the children.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final grows = children.any((child) => child is Flexible);
    final list = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && spacing > 0) list.add(SizedBox.square(dimension: spacing));
      list.add(children[i]);
    }
    return GlassPressable(
      child: Glass(
        borderRadius: double.infinity,
        padding: EdgeInsets.all(padding),
        child: Flex(direction: direction, mainAxisSize: grows ? MainAxisSize.max : MainAxisSize.min, children: list),
      ),
    );
  }
}

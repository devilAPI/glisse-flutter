import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'glass.dart';
import 'input.dart';

/// An inset grouped list on a card of glass, as iOS 26's settings: rows
/// parted by hairlines that start where their text does, under a muted
/// [header] and over a muted [footer].
class GlassListSection extends StatelessWidget {
  const GlassListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.borderRadius = 26,
  });

  final Widget? header;
  final Widget? footer;

  /// The rows, usually [GlassListTile]s.
  final List<Widget> children;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final muted = DefaultTextStyle.of(context).style.merge(theme.textStyle).copyWith(
          color: theme.muted,
          fontSize: 13,
          height: 1.3,
        );
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        final child = children[i];
        final inset = child is GlassListTile && child.leading != null ? 16.0 + 28 + 12 : 16.0;
        rows.add(Padding(
          padding: EdgeInsetsDirectional.only(start: inset),
          child: Container(height: 0.5, color: theme.separator),
        ));
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20, end: 20, bottom: 7),
            child: DefaultTextStyle(style: muted, child: Semantics(header: true, child: header!)),
          ),
        Glass(
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child:
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20, end: 20, top: 7),
            child: DefaultTextStyle(style: muted, child: footer!),
          ),
      ],
    );
  }
}

/// A row of a [GlassListSection]: an optional [leading] icon, a [title] over
/// a [subtitle], and a [trailing] value or control. Tappable rows light up
/// while pressed.
class GlassListTile extends StatefulWidget {
  const GlassListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  /// Sized 28px across, such as an icon on a coloured square.
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Shows a chevron at the end, for a row that leads somewhere.
  final bool showChevron;

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final tappable = widget.onTap != null;
    final fill = _pressed
        ? theme.highlight
        : (_hovered || _focused) && tappable
            ? theme.highlight.withValues(alpha: theme.highlight.a * 0.6)
            : const Color(0x00000000);

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: base.copyWith(color: theme.foreground, fontSize: 16, height: 1.25),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          child: widget.title,
        ),
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DefaultTextStyle(
              style: base.copyWith(color: theme.muted, fontSize: 13, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              child: widget.subtitle!,
            ),
          ),
      ],
    );

    final Widget row = AnimatedContainer(
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.ease,
      color: fill,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: theme.fill, size: 22),
              child: SizedBox.square(dimension: 28, child: Center(child: widget.leading)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: text),
          if (widget.trailing != null) ...[
            const SizedBox(width: 10),
            DefaultTextStyle(
              style: base.copyWith(color: theme.muted, fontSize: 16),
              child: IconTheme.merge(data: IconThemeData(color: theme.muted, size: 20), child: widget.trailing!),
            ),
          ],
          if (widget.showChevron) ...[
            const SizedBox(width: 8),
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: GlassGlyph.chevron(color: theme.muted, size: 14),
            ),
          ],
        ],
      ),
    );

    if (!tappable) return Semantics(container: true, child: row);
    return Semantics(
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}

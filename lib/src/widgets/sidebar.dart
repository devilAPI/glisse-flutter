import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';

/// One destination in a [GlassSidebar].
@immutable
class GlassSidebarItem {
  /// Creates a sidebar item.
  const GlassSidebarItem({required this.icon, required this.label, this.trailing});

  /// Shown at the row's start.
  final Widget icon;

  /// The row's text.
  final String label;

  /// Shown at the row's end, such as a count.
  final Widget? trailing;
}

/// A tall pane of glass listing destinations, as iPadOS and macOS 26's
/// sidebars: the selection is a plate that springs from row to row.
class GlassSidebar extends StatefulWidget {
  /// Creates a sidebar.
  const GlassSidebar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.header,
    this.width = 240,
    this.rowHeight = 36,
  });

  /// The destinations, in order.
  final List<GlassSidebarItem> items;

  /// The selected item's index, or -1 for none.
  final int selected;

  /// Called with the index of the item chosen.
  final ValueChanged<int> onSelected;

  /// Shown above the items, such as a title or a search field.
  final Widget? header;

  /// The sidebar's width.
  final double width;

  /// Each row's height.
  final double rowHeight;

  @override
  State<GlassSidebar> createState() => _GlassSidebarState();
}

const double _gap = 2;

class _GlassSidebarState extends State<GlassSidebar> with SingleTickerProviderStateMixin {
  late final GlassSpring _plate = GlassSpring(
    vsync: this,
    value: widget.selected.toDouble(),
    stiffness: 640,
    damping: 46,
  );
  int _hovered = -1;
  final FocusNode _focus = FocusNode(debugLabel: 'GlassSidebar');
  bool _focused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _plate.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      // Appearing, the plate lands at once; moving, it springs.
      _plate.set(widget.selected.toDouble(), instant: oldWidget.selected < 0);
    }
  }

  @override
  void dispose() {
    _plate.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int by) {
    final n = widget.items.length;
    if (n == 0) return;
    final from = widget.selected < 0 ? (by > 0 ? -1 : n) : widget.selected;
    widget.onSelected((from + by).clamp(0, n - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final row = widget.rowHeight;

    final rows = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final selected = i == widget.selected;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i < widget.items.length - 1 ? _gap : 0),
        child: Semantics(
          button: true,
          selected: selected,
          label: item.label,
          excludeSemantics: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = i),
            onExit: (_) => setState(() => _hovered = -1),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: row,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(row / 3),
                  color: _hovered == i && !selected
                      ? theme.highlight.withValues(alpha: theme.highlight.a * 0.7)
                      : const Color(0x00000000),
                ),
                child: Row(children: [
                  IconTheme.merge(
                    data: IconThemeData(color: selected ? theme.fill : theme.muted, size: 19),
                    child: SizedBox.square(dimension: 22, child: Center(child: item.icon)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: theme.foreground,
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (item.trailing != null)
                    DefaultTextStyle(
                      style: base.copyWith(color: theme.muted, fontSize: 13),
                      child: item.trailing!,
                    ),
                ]),
              ),
            ),
          ),
        ),
      ));
    }

    final list = Stack(
      children: [
        if (widget.selected >= 0)
          AnimatedBuilder(
            animation: _plate,
            builder: (context, _) => Positioned(
              left: 0,
              right: 0,
              top: _plate.value * (row + _gap),
              height: row,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(row / 3),
                  color: theme.selection,
                  border: _focused ? Border.all(color: theme.ring, width: 2) : null,
                ),
              ),
            ),
          ),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ],
    );

    return Focus(
      focusNode: _focus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _step(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _step(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Glass(
        width: widget.width,
        borderRadius: 24,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: DefaultTextStyle(
                  style: base.copyWith(color: theme.foreground, fontSize: 17, fontWeight: FontWeight.w700),
                  child: widget.header!,
                ),
              ),
            list,
          ],
        ),
      ),
    );
  }
}

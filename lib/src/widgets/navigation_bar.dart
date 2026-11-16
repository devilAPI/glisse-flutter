import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'button.dart';
import 'input.dart';

/// iOS 26's floating top bar: no bar at all, but glass capsules for the
/// leading and trailing buttons floating over the content, and a title
/// between them.
///
/// With [largeTitle] the title sits under the buttons, large and leading,
/// as at the top of an iOS list.
class GlassNavigationBar extends StatelessWidget {
  /// Creates a navigation bar.
  const GlassNavigationBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const [],
    this.largeTitle = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  /// Such as a [GlassBackButton].
  final Widget? leading;

  /// Shown between the buttons, or large under them with [largeTitle].
  final Widget? title;

  /// Trailing buttons: [GlassButton]s, or a `GlassButtonGroup` (height 44) to share one capsule.
  final List<Widget> actions;

  /// Whether the title sits large under the buttons.
  final bool largeTitle;

  /// The space round the bar.
  final EdgeInsetsGeometry padding;

  /// The height of the row of buttons, without the large title.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    Widget? small;
    if (title != null && !largeTitle) {
      small = DefaultTextStyle(
        style: base.copyWith(color: theme.foreground, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        child: Semantics(header: true, child: title!),
      );
    }
    final trailing = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) trailing.add(const SizedBox(width: 8));
      trailing.add(actions[i]);
    }
    Widget bar = SizedBox(
      height: height,
      child: NavigationToolbar(
        leading: leading,
        middle: small,
        trailing: trailing.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        middleSpacing: 12,
      ),
    );
    if (largeTitle && title != null) {
      bar = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: DefaultTextStyle(
              style: base.copyWith(
                color: theme.foreground,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                height: 1.15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Semantics(header: true, child: title!),
            ),
          ),
        ],
      );
    }
    return Padding(padding: padding, child: bar);
  }
}

/// A back button for a [GlassNavigationBar]: a chevron in a glass circle,
/// or a capsule with a [label].
class GlassBackButton extends StatelessWidget {
  /// Creates a back button.
  const GlassBackButton({super.key, this.onPressed, this.label});

  /// Defaults to popping the nearest route.
  final VoidCallback? onPressed;

  /// Text beside the chevron. Null shows a circle with the chevron alone.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final chevron = Transform.flip(
      flipX: Directionality.of(context) == TextDirection.ltr,
      child: GlassGlyph.chevron(color: theme.foreground, size: 20),
    );
    return GlassButton(
      height: GlassNavigationBar.height,
      icon: chevron,
      semanticLabel: label ?? 'Back',
      padding: label == null ? null : const EdgeInsets.only(left: 10, right: 16),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      child: label == null ? null : Text(label!, style: const TextStyle(fontSize: 16)),
    );
  }
}

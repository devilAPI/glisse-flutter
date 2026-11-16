import 'package:flutter/widgets.dart';

import '../rendering/liquid_glass.dart';
import 'segments.dart';

export 'segments.dart' show GlassSegment;

/// A row of tabs on glass, as iOS 26's tab bar: the selection springs
/// between them, follows a drag, and lifts into a lens while held. Tabs with
/// an icon show it above a small label, the selected one in the accent.
class GlassTabBar<T> extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.mode = GlassMode.auto,
  });

  final List<GlassSegment<T>> items;

  /// The selected tab's value, or null for none.
  final T? value;

  /// Called when a tab is chosen, even the selected one again. Null disables the bar.
  final ValueChanged<T>? onChanged;
  final String? semanticLabel;
  final GlassMode mode;

  @override
  Widget build(BuildContext context) => SegmentsView<T>(
        kind: SegmentsKind.tabBar,
        items: items,
        value: value,
        onChanged: onChanged,
        semanticLabel: semanticLabel,
        mode: mode,
      );
}

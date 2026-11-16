import 'package:flutter/widgets.dart';

import '../rendering/liquid_glass.dart';
import 'segments.dart';

export 'segments.dart' show GlassSegment;

/// A choice between a few options, as iOS 26's segmented control: a thumb on
/// a glass track that, held or dragged, lifts into a lens over the labels.
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.mode = GlassMode.auto,
  });

  final List<GlassSegment<T>> segments;

  /// The selected segment's value, or null for none.
  final T? value;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;
  final String? semanticLabel;
  final GlassMode mode;

  @override
  Widget build(BuildContext context) => SegmentsView<T>(
        kind: SegmentsKind.segmented,
        items: segments,
        value: value,
        onChanged: onChanged,
        semanticLabel: semanticLabel,
        mode: mode,
      );
}

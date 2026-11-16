import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Takes touches a little outside its child's box, without taking any more
/// room: a bigger touch target for a small control, as a CSS `::before`
/// that hangs outside an element gives it.
///
/// Only touches its parent passes down reach it, so the parent must itself
/// cover the padding (most layouts with room around the control do).
class HitPadding extends SingleChildRenderObjectWidget {
  /// Lets [child] take touches up to [padding] outside its box.
  const HitPadding({super.key, required this.padding, super.child});

  /// How far outside the child's box touches still reach it, in logical px.
  final EdgeInsets padding;

  @override
  RenderHitPadding createRenderObject(BuildContext context) => RenderHitPadding(padding);

  @override
  void updateRenderObject(BuildContext context, RenderHitPadding renderObject) {
    renderObject.padding = padding;
  }
}

/// The render object of [HitPadding].
class RenderHitPadding extends RenderProxyBox {
  /// Creates a box that takes touches up to [padding] outside its child.
  RenderHitPadding(this.padding);

  /// How far outside the box touches still reach the child, in logical px.
  EdgeInsets padding;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.isEmpty) return false;
    final area = padding.inflateRect(Offset.zero & size);
    if (!area.contains(position)) return false;
    // The child takes it at the nearest point of its own box.
    final inside = Offset(
      position.dx.clamp(0.0, (size.width - 0.001).clamp(0.0, double.infinity)).toDouble(),
      position.dy.clamp(0.0, (size.height - 0.001).clamp(0.0, double.infinity)).toDouble(),
    );
    if (child != null && child!.hitTest(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

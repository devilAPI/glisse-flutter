import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Takes touches a little outside its child's box, without taking any more
/// room: a bigger touch target for a small control, as a CSS `::before`
/// that hangs outside an element gives it.
///
/// Only touches its parent passes down reach it, so the parent must itself
/// cover the padding (most layouts with room around the control do).
class HitPadding extends SingleChildRenderObjectWidget {
  const HitPadding({super.key, required this.padding, super.child});

  final EdgeInsets padding;

  @override
  RenderHitPadding createRenderObject(BuildContext context) => RenderHitPadding(padding);

  @override
  void updateRenderObject(BuildContext context, RenderHitPadding renderObject) {
    renderObject.padding = padding;
  }
}

class RenderHitPadding extends RenderProxyBox {
  RenderHitPadding(this.padding);

  EdgeInsets padding;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final area = padding.inflateRect(Offset.zero & size);
    if (!area.contains(position)) return false;
    // The child takes it at the nearest point of its own box.
    final inside = Offset(
      position.dx.clamp(0.0, size.width - 0.001).toDouble(),
      position.dy.clamp(0.0, size.height - 0.001).toDouble(),
    );
    if (child != null && child!.hitTest(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

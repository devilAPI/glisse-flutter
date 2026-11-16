import 'package:flutter/widgets.dart';

import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';

/// The frost a lifted switch or slider thumb lays over the page under it, as
/// Glisse's thumb's `backdrop-filter`: a blur that clears from 2px to 0.5px
/// and a brightening that fades as it lifts, and a saturation of 1.5. The
/// thumb's lens draws the track over it.
class ThumbFrost extends StatelessWidget {
  const ThumbFrost({super.key, required this.rect, required this.lift});

  /// The thumb as placed, in its control's px.
  final Rect rect;

  /// How far the thumb is lifted, from 0 to 1.
  final double lift;

  @override
  Widget build(BuildContext context) {
    final lifted = lift.clamp(0.0, 1.0);
    final settled = 1 - lifted;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: LiquidGlassBox(
          radius: double.infinity,
          style: GlassStyle(
            tint: const Color(0x00000000),
            edge: const Color(0x00000000),
            drop: const Color(0x00000000),
            rimShine: 0,
            blur: 2 * settled + 0.5 * lifted,
            saturation: 1.5,
            brightness: 1 + 0.15 * settled,
            bend: 0,
            dispersion: 0,
            spec: LensSpec.glass,
            rim: LensRim.none,
            amount: 0,
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// CSS's blur radius as a Gaussian's deviation.
double cssBlurToSigma(double blur) => blur <= 0 ? 0 : blur / 2;

/// A rounded rectangle whose corners are [radius], or a capsule when it is
/// infinite.
RRect roundedRect(Rect rect, double radius) {
  final r = math.min(radius, math.min(rect.width, rect.height) / 2);
  return RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, r)));
}

/// An outer box shadow, as CSS draws it: only outside the box.
void paintDropShadow(
  Canvas canvas,
  RRect rrect, {
  required Color color,
  Offset offset = Offset.zero,
  double blur = 0,
  double spread = 0,
}) {
  if (color.a <= 0) return;
  final sigma = cssBlurToSigma(blur);
  final shadow = rrect.inflate(spread).shift(offset);
  final reach = sigma * 3 + spread.abs() + offset.distance + 2;
  canvas.save();
  final outside = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(rrect.outerRect.inflate(reach))
    ..addRRect(rrect);
  canvas.clipPath(outside);
  final paint = Paint()..color = color;
  if (sigma > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
  canvas.drawRRect(shadow, paint);
  canvas.restore();
}

/// An inset box shadow, as CSS draws it: only inside the box.
void paintInsetShadow(
  Canvas canvas,
  RRect rrect, {
  required Color color,
  Offset offset = Offset.zero,
  double blur = 0,
  double spread = 0,
}) {
  if (color.a <= 0) return;
  final sigma = cssBlurToSigma(blur);
  canvas.save();
  canvas.clipRRect(rrect);
  final hole = rrect.deflate(spread).shift(offset);
  final reach = sigma * 3 + spread.abs() + offset.distance + 4;
  final ring = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(rrect.outerRect.inflate(reach))
    ..addRRect(hole);
  final paint = Paint()..color = color;
  if (sigma > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
  canvas.drawPath(ring, paint);
  canvas.restore();
}

/// CSS's `saturate()` as a colour matrix.
List<double> saturationMatrix(double s) => <double>[
      0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
      0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
      0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
      0, 0, 0, 1, 0,
    ];

/// CSS's `brightness()` then `saturate()`, as one colour matrix.
List<double> brightnessSaturationMatrix(double b, double s) {
  final m = saturationMatrix(s);
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      m[row * 5 + col] *= b;
    }
  }
  return m;
}

/// A frost filter: a blur, then saturation, as CSS's `backdrop-filter`.
ui.ImageFilter frostFilter({required double sigma, double saturation = 1, double brightness = 1}) {
  final blur = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror);
  if (saturation == 1 && brightness == 1) return blur;
  return ui.ImageFilter.compose(
    outer: ColorFilter.matrix(brightnessSaturationMatrix(brightness, saturation)),
    inner: blur,
  );
}

/// Mixes [a] towards [b] by [t], as CSS's `color-mix(in srgb, ...)`.
Color mixColor(Color a, Color b, double t) => Color.lerp(a, b, t)!;

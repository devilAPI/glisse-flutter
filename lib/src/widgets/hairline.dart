import 'package:flutter/widgets.dart';

/// The thickness of a hairline: half a point, as iOS draws separators, but
/// never under one device pixel, where it would fade or vanish.
double hairline(BuildContext context) {
  final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
  final pixel = 1 / ratio;
  return pixel > 0.5 ? pixel : 0.5;
}

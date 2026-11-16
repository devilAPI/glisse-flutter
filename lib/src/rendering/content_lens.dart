import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'lens.dart';
import 'shadows.dart';

/// Records [draw] (in logical px over [size]) into an image at [pixelRatio],
/// for a lens to bend. Content of a widget's own, like a switch's track or a
/// tab bar's labels, is small, so recording it again each frame a lens moves
/// is cheap.
ui.Image recordImage(Size size, double pixelRatio, void Function(Canvas canvas) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    math.max(1, (size.width * pixelRatio).ceil()),
    math.max(1, (size.height * pixelRatio).ceil()),
  );
  picture.dispose();
  return image;
}

/// Draws [image], which covers [imageRect] in local px, through the lens
/// [draw] describes, over [draw.rect] only: what's outside the image is clear.
void paintContentLens(
  Canvas canvas,
  ui.FragmentShader shader, {
  required LensDraw draw,
  required ui.Image image,
  required Rect imageRect,
}) {
  draw.onImage(uvFor(imageRect: imageRect)).apply(shader, image: image);
  canvas.drawRect(draw.rect.inflate(1), Paint()..shader = shader);
}

/// Hides what's under a lens of [rrect]'s shape, inside a layer the caller
/// saved: what the lens shows stands in for it.
void cutOut(Canvas canvas, RRect rrect) {
  canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.dstOut);
}

/// The glass thumb of a switch or slider, as Glisse draws it: a white knob at
/// rest that, lifted, clears into a lens whose rim catches the light.
///
/// [rect] is the thumb at its own, unscaled size; [scale] scales it about
/// its centre. Paints the shadows and face; the lens itself is drawn before
/// by the caller through [paintContentLens].
void paintThumbChrome(
  Canvas canvas, {
  required Rect rect,
  required double scale,
  required double lift,
}) {
  final settled = 1 - lift.clamp(0.0, 1.0);
  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  canvas.scale(scale);
  canvas.translate(-rect.center.dx, -rect.center.dy);
  final rrect = roundedRect(rect, double.infinity);
  paintDropShadow(canvas, rrect, color: const Color.fromRGBO(0, 0, 0, 0.2), offset: const Offset(0, 6), blur: 24);
  paintInsetShadow(canvas, rrect, color: const Color.fromRGBO(255, 255, 255, 0.5), spread: 1.5);
  paintInsetShadow(canvas, rrect,
      color: const Color.fromRGBO(255, 255, 255, 0.45), offset: const Offset(0, 2), blur: 1);
  paintInsetShadow(canvas, rrect, color: const Color.fromRGBO(0, 0, 0, 0.09), offset: const Offset(2, 7), blur: 24);
  paintInsetShadow(canvas, rrect,
      color: const Color.fromRGBO(255, 255, 255, 0.16), offset: const Offset(-2, -7), blur: 24);
  final face = 1 - 0.85 * (1 - settled);
  canvas.drawRRect(rrect, Paint()..color = Color.fromRGBO(255, 255, 255, face.clamp(0.0, 1.0)));
  canvas.restore();
}

/// A rect scaled by [scale] about its centre.
Rect scaleAbout(Rect rect, double scale) => Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    );

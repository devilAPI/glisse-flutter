import 'dart:js_interop';

@JS('document')
external _Document get _document;

extension type _Document._(JSObject _) implements JSObject {
  external _Canvas createElement(String tag);
}

extension type _Canvas._(JSObject _) implements JSObject {
  external set width(int value);
  external set height(int value);
  external _Context2D? getContext(String id);
}

extension type _Context2D._(JSObject _) implements JSObject {
  external set fillStyle(JSString value);
  external void fillRect(num x, num y, num width, num height);
  external _ImageData getImageData(num x, num y, num width, num height);
}

extension type _ImageData._(JSObject _) implements JSObject {
  external JSUint8ClampedArray get data;
}

/// Draws one red pixel on a canvas of its own and reads it back. A browser
/// that blocks reading canvases back (to resist fingerprinting) hands back
/// blank or random pixels instead; one that only adds noise, as Brave does,
/// still reads as red.
bool canReadPixelsBack() {
  try {
    final canvas =
        _document.createElement('canvas')
          ..width = 1
          ..height = 1;
    final context = canvas.getContext('2d');
    if (context == null) return false;
    context
      ..fillStyle = 'rgb(255, 0, 0)'.toJS
      ..fillRect(0, 0, 1, 1);
    final pixel = context.getImageData(0, 0, 1, 1).data.toDart;
    return pixel.length >= 4 && pixel[0] > 200 && pixel[1] < 60 && pixel[2] < 60 && pixel[3] > 200;
  } catch (_) {
    return false;
  }
}

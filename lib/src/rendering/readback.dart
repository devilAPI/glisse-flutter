import 'readback_native.dart' if (dart.library.js_interop) 'readback_web.dart' as platform;

/// Whether this platform can read a drawn picture back into an image, as
/// `Picture.toImageSync` does. It always can, except in a browser that
/// blocks reading pixels back from a canvas, such as Firefox or LibreWolf
/// with `privacy.resistFingerprinting`. There, CanvasKit fails inside
/// `toImageSync` and is left broken for every draw after it, so glass must
/// not try.
bool get canReadPixelsBack => _canReadPixelsBack ??= platform.canReadPixelsBack();
bool? _canReadPixelsBack;

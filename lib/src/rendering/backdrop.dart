import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'lens.dart' show GlassShaders;

/// Content that glass above it refracts, on every platform.
///
/// Glass can bend only what it can read. Impeller (iOS, Android, macOS) lets
/// glass read the live backdrop behind it; elsewhere (Skia, the web, Linux and
/// Windows) a [GlassBackdrop] keeps a copy of its [background] for the glass
/// in its [child] to bend, as Glisse's `data-glisse-backdrop` marks content
/// for its glass to bend in every browser. The copy is taken again whenever
/// the background paints anything new, so it may move, scroll and animate.
///
/// ```dart
/// GlassBackdrop(
///   background: Image.asset('wallpaper.jpg', fit: BoxFit.cover),
///   child: Center(child: GlassButton(child: Text('Continue'), onPressed: () {})),
/// )
/// ```
class GlassBackdrop extends StatefulWidget {
  /// Lays [background] under [child] and keeps a copy of it for glass to bend.
  const GlassBackdrop({super.key, required this.background, required this.child, this.pixelRatio, this.enabled = true});

  /// What the glass in [child] bends: laid out to fill this widget, behind [child].
  final Widget background;

  /// The glass, and anything else over the background.
  ///
  /// The backdrop takes this child's size, so give it one that fills the
  /// space (a [Stack] of positioned children, a [Center], a
  /// `SizedBox.expand()`), or the background shrinks with it.
  final Widget child;

  /// The copy's resolution, in device pixels per logical pixel. Defaults to
  /// the display's, at most 3. Lower is cheaper and blurrier.
  final double? pixelRatio;

  /// Whether to copy the background at all. Off, glass frosts the live
  /// backdrop where it can and paints its rim.
  final bool enabled;

  /// The nearest backdrop's controller, if any.
  static GlassBackdropController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassBackdropScope>()?.controller;

  /// Gives the glass in [child] a backdrop found elsewhere, as for an overlay
  /// laid out outside the [GlassBackdrop] it floats over.
  static Widget inherit({required GlassBackdropController? controller, required Widget child}) =>
      _GlassBackdropScope(controller: controller, child: child);

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop> {
  final GlassBackdropController _controller = GlassBackdropController._();

  @override
  void dispose() {
    _controller._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The copy's resolution follows the theme's quality: glass frosts it,
    // so fewer pixels than the display's are rarely seen, and every pixel is
    // copied each time it changes. On the web each is also read back from the
    // GPU, which stalls the page (in Firefox, about half a microsecond a
    // pixel), so below high quality the web copies at half the display's.
    final display = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final quality = GlassTheme.of(context).effectiveQuality;
    final ratio =
        widget.pixelRatio ??
        (kIsWeb
            ? (quality == GlassQuality.high ? display.clamp(1.0, 2.0) : (display * 0.5).clamp(0.5, 1.0))
            : display.clamp(1.0, switch (quality) {
              GlassQuality.low => 1.0,
              GlassQuality.medium => 2.0,
              GlassQuality.high || GlassQuality.auto => 3.0,
            }));
    _controller._enabled = widget.enabled;
    return _GlassBackdropScope(
      controller: widget.enabled ? _controller : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: _CaptureBoundary(
              controller: _controller,
              pixelRatio: ratio,
              enabled: widget.enabled,
              // Glass in the background reads whatever is behind this
              // backdrop, never its own copy, which it is part of.
              child: _GlassBackdropScope(controller: GlassBackdrop.maybeOf(context), child: widget.background),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _GlassBackdropScope extends InheritedWidget {
  const _GlassBackdropScope({required this.controller, required super.child});

  final GlassBackdropController? controller;

  @override
  bool updateShouldNotify(_GlassBackdropScope oldWidget) => controller != oldWidget.controller;
}

/// The copy of a [GlassBackdrop]'s background, for the glass over it.
class GlassBackdropController extends ChangeNotifier {
  GlassBackdropController._();

  ui.Image? _image;
  double _ratio = 1;
  // Frosted versions of the copy, by their blur in quarter logical px.
  final Map<int, ui.Image> _frosted = {};
  // How long frosting the latest copy took, which counts towards its cost.
  Duration _frostCost = Duration.zero;
  RenderGlassCapture? _render;
  bool _enabled = true;
  int _users = 0;
  bool _disposed = false;

  /// The latest copy, covering the background's whole box.
  ui.Image? get image => _enabled && !_disposed ? _image : null;

  /// Whether the backdrop that made this is still around. Overlays can
  /// outlive the page whose backdrop they carry.
  bool get isActive => !_disposed;

  /// The background's render box, for mapping glass into it.
  RenderBox? get renderBox => _render;

  /// The copy, blurred by [sigma] logical px, made once per copy and shared
  /// by every glass that frosts by that much. Glass samples it once per
  /// pixel rather than blurring the copy itself, which costs it dozens.
  ui.Image? frosted(double sigma) {
    final image = this.image;
    // On the web every copy is read back from the GPU, which stalls the page
    // (in Firefox, about half a second for a screenful). Glass blurs the copy
    // itself there, on the GPU, rather than wait for a frosted one.
    if (image == null || sigma < 0.25 || kIsWeb) return image;
    final key = (sigma * 4).round();
    final hit = _frosted[key];
    if (hit != null) return hit;
    if (_frosted.length >= 4) _clearFrosted();
    final watch = Stopwatch()..start();
    final deviation = key / 4 * _ratio;
    final width = image.width;
    final height = image.height;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(
      image,
      Offset.zero,
      Paint()
        ..filterQuality = FilterQuality.low
        ..imageFilter = ui.ImageFilter.blur(sigmaX: deviation, sigmaY: deviation, tileMode: TileMode.clamp),
    );
    final picture = recorder.endRecording();
    final frosted = picture.toImageSync(width, height);
    picture.dispose();
    _frostCost += watch.elapsed;
    return _frosted[key] = frosted;
  }

  void _clearFrosted() {
    for (final image in _frosted.values) {
      image.dispose();
    }
    _frosted.clear();
  }

  /// Glass reading the copy registers, so no copy is taken while none is.
  void addUser() {
    _users++;
    if (_users == 1) _render?._requestCapture();
  }

  /// Glass stops reading the copy, undoing one [addUser].
  void removeUser() => _users = (_users - 1).clamp(0, 1 << 30);

  /// Whether any glass is reading the copy.
  bool get hasUsers => _users > 0;

  void _setImage(ui.Image image, double ratio) {
    if (_disposed) {
      image.dispose();
      return;
    }
    final old = _image;
    _image = image;
    _ratio = ratio;
    _frostCost = Duration.zero;
    _clearFrosted();
    notifyListeners();
    // A picture already recorded with the old copy keeps its own reference.
    old?.dispose();
  }

  void _dispose() {
    _disposed = true;
    _clearFrosted();
    _image?.dispose();
    _image = null;
    dispose();
  }
}

class _CaptureBoundary extends SingleChildRenderObjectWidget {
  const _CaptureBoundary({required this.controller, required this.pixelRatio, required this.enabled, super.child});

  final GlassBackdropController controller;
  final double pixelRatio;
  final bool enabled;

  @override
  RenderGlassCapture createRenderObject(BuildContext context) =>
      RenderGlassCapture(controller: controller, pixelRatio: pixelRatio, enabled: enabled);

  @override
  void updateRenderObject(BuildContext context, RenderGlassCapture renderObject) {
    renderObject
      ..controller = controller
      ..pixelRatio = pixelRatio
      ..enabled = enabled;
  }
}

/// A repaint boundary that copies itself after every frame in which anything
/// under it changed: its layer is asked to add itself to the scene only then.
class RenderGlassCapture extends RenderProxyBox {
  /// Creates a boundary that copies itself for [controller] at [pixelRatio].
  RenderGlassCapture({required GlassBackdropController controller, required double pixelRatio, required bool enabled})
    : _controller = controller,
      _pixelRatio = pixelRatio,
      _enabled = enabled {
    _controller._render = this;
  }

  GlassBackdropController _controller;

  /// The controller that receives the copies.
  set controller(GlassBackdropController value) {
    if (value == _controller) return;
    if (_controller._render == this) _controller._render = null;
    _controller = value;
    _controller._render = this;
    _requestCapture();
  }

  double _pixelRatio;

  /// The copy's resolution, in device pixels per logical pixel.
  set pixelRatio(double value) {
    if (value == _pixelRatio) return;
    _pixelRatio = value;
    _requestCapture();
  }

  bool _enabled;

  /// Whether to copy at all.
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _requestCapture();
  }

  bool _scheduled = false;
  // Copying adds the layer to a scene of its own, which isn't a change.
  bool _capturing = false;

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({required covariant OffsetLayer? oldLayer}) {
    final layer = oldLayer is _CaptureLayer ? oldLayer : _CaptureLayer();
    layer.onAddToScene = _requestCapture;
    return layer;
  }

  // On the web a copy waits for the GPU to hand its pixels back, which can
  // take a large part of a second in Firefox. A background that changes
  // every frame, as one with a spinner in it does, would then copy every
  // frame and bring the page to a crawl. So there the next copy waits four
  // times as long as the last one took: copying takes at most a fifth of
  // the time, and the glass shows a copy a little behind meanwhile. Native
  // copies stay on the GPU and don't wait.
  Duration _lastCost = Duration.zero;
  final Stopwatch _sinceCopy = Stopwatch();
  Timer? _rest;

  Duration get _waitLeft {
    if (!kIsWeb || !_sinceCopy.isRunning) return Duration.zero;
    final cost = _lastCost + _controller._frostCost;
    if (cost < const Duration(milliseconds: 4)) return Duration.zero;
    return cost * 4 - _sinceCopy.elapsed;
  }

  void _requestCapture() {
    if (_capturing || _scheduled || !attached || !_enabled) return;
    final wait = _waitLeft;
    if (wait > Duration.zero) {
      _rest ??= Timer(wait, () {
        _rest = null;
        _requestCapture();
      });
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _capture();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _capture() {
    if (!attached || !_enabled || !hasSize || size.isEmpty) return;
    if (!_controller.hasUsers) return;
    // Where the browser blocks reading pictures back, there's no copy, and
    // glass frosts the live page instead.
    if (!GlassShaders.canRecordImages) return;
    final layer = this.layer;
    if (layer is! OffsetLayer || !layer.attached) return;
    try {
      _capturing = true;
      final watch = Stopwatch()..start();
      final image = layer.toImageSync(Offset.zero & size, pixelRatio: _pixelRatio);
      _lastCost = watch.elapsed;
      _sinceCopy
        ..reset()
        ..start();
      _capturing = false;
      _controller._setImage(image, _pixelRatio);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'glisse',
          context: ErrorDescription('while copying a GlassBackdrop'),
        ),
      );
    } finally {
      _capturing = false;
    }
  }

  @override
  void detach() {
    _scheduled = false;
    _rest?.cancel();
    _rest = null;
    super.detach();
  }

  @override
  void dispose() {
    if (_controller._render == this) _controller._render = null;
    super.dispose();
  }
}

class _CaptureLayer extends OffsetLayer {
  VoidCallback? onAddToScene;

  @override
  void addToScene(ui.SceneBuilder builder) {
    super.addToScene(builder);
    onAddToScene?.call();
  }
}

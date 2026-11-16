import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
    final ratio = widget.pixelRatio ?? (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1).clamp(1.0, 3.0);
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

  /// Glass reading the copy registers, so no copy is taken while none is.
  void addUser() {
    _users++;
    if (_users == 1) _render?._requestCapture();
  }

  /// Glass stops reading the copy, undoing one [addUser].
  void removeUser() => _users = (_users - 1).clamp(0, 1 << 30);

  /// Whether any glass is reading the copy.
  bool get hasUsers => _users > 0;

  void _setImage(ui.Image image) {
    if (_disposed) {
      image.dispose();
      return;
    }
    final old = _image;
    _image = image;
    notifyListeners();
    // A picture already recorded with the old copy keeps its own reference.
    old?.dispose();
  }

  void _dispose() {
    _disposed = true;
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

  void _requestCapture() {
    if (_capturing || _scheduled || !attached || !_enabled) return;
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
    final layer = this.layer;
    if (layer is! OffsetLayer || !layer.attached) return;
    try {
      _capturing = true;
      final image = layer.toImageSync(Offset.zero & size, pixelRatio: _pixelRatio);
      _capturing = false;
      _controller._setImage(image);
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

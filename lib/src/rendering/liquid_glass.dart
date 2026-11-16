import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'backdrop.dart';
import 'lens.dart';
import 'shadows.dart';

/// How glass reads what's behind it.
enum GlassMode {
  /// A [GlassBackdrop]'s copy where there is one; else, on Impeller, the live
  /// backdrop; else [frost].
  auto,

  /// Only a [GlassBackdrop]'s copy; [frost] without one.
  captured,

  /// Only the live backdrop, through Impeller's shader filters; [frost] where
  /// they aren't supported.
  backdropFilter,

  /// No bend: the backdrop blurred and saturated under the glass's tint and
  /// lit rim, which every platform can draw.
  frost,
}

/// How a piece of glass looks, beyond its shape.
@immutable
class GlassStyle {
  const GlassStyle({
    required this.tint,
    required this.edge,
    required this.drop,
    required this.rimShine,
    required this.blur,
    required this.saturation,
    required this.bend,
    required this.dispersion,
    this.brightness = 1,
    this.spec = LensSpec.glass,
    this.rim = LensRim.glass,
    this.amount = 1,
    this.mode = GlassMode.auto,
  });

  final Color tint;
  final Color edge;
  final Color drop;
  final double rimShine;
  final double blur;
  final double saturation;
  final double brightness;

  /// The lens's strength, overriding [spec]'s.
  final double bend;
  final double dispersion;
  final LensSpec spec;
  final LensRim rim;

  /// How far the glass bends now, from 0 to 1.
  final double amount;
  final GlassMode mode;

  @override
  bool operator ==(Object other) =>
      other is GlassStyle &&
      other.tint == tint &&
      other.edge == edge &&
      other.drop == drop &&
      other.rimShine == rimShine &&
      other.blur == blur &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.bend == bend &&
      other.dispersion == dispersion &&
      other.spec == spec &&
      other.rim == rim &&
      other.amount == amount &&
      other.mode == mode;

  @override
  int get hashCode =>
      Object.hash(tint, edge, drop, rimShine, blur, saturation, brightness, bend, dispersion, spec, rim, amount, mode);
}

/// The render object behind every piece of Glisse glass: a rounded
/// rectangle that bends, frosts, tints and lights what's behind it, then
/// paints its child.
class RenderLiquidGlass extends RenderProxyBox {
  RenderLiquidGlass({
    required double radius,
    required GlassStyle style,
    required double devicePixelRatio,
    GlassBackdropController? backdrop,
    RenderBox? child,
  })  : _radius = radius,
        _style = style,
        _devicePixelRatio = devicePixelRatio,
        _backdrop = backdrop,
        super(child);

  double _radius;
  double get radius => _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  GlassStyle _style;
  GlassStyle get style => _style;
  set style(GlassStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  GlassBackdropController? _backdrop;
  set backdrop(GlassBackdropController? value) {
    if (value == _backdrop) return;
    if (attached) _unlisten();
    _backdrop = value;
    if (attached) _listen();
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  ui.FragmentShader? _filterShader;
  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _filterLayer = LayerHandle<BackdropFilterLayer>();

  void _listen() {
    _backdrop?.addListener(markNeedsPaint);
    _backdrop?.addUser();
  }

  void _unlisten() {
    _backdrop?.removeListener(markNeedsPaint);
    _backdrop?.removeUser();
  }

  void _onShaderReady() => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    GlassShaders.ready.addListener(_onShaderReady);
    GlassShaders.load();
    _listen();
  }

  @override
  void detach() {
    GlassShaders.ready.removeListener(_onShaderReady);
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _clipRectLayer.layer = null;
    _filterLayer.layer = null;
    _shader?.dispose();
    _filterShader?.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  RRect _rrect(Rect rect) => roundedRect(rect, _radius);

  double get _effectiveRadius => math.min(_radius, math.min(size.width, size.height) / 2);

  GlassMode _resolve() {
    final mode = _style.mode;
    final ready = GlassShaders.program != null;
    if (mode == GlassMode.frost || !ready) return GlassMode.frost;
    final copy = _backdrop?.image != null && _backdrop?.renderBox?.attached == true;
    if (mode == GlassMode.captured) return copy ? GlassMode.captured : GlassMode.frost;
    if (mode == GlassMode.auto && copy) return GlassMode.captured;
    if (ui.ImageFilter.isShaderFilterSupported) return GlassMode.backdropFilter;
    return GlassMode.frost;
  }

  LensDraw _draw({
    required Rect rect,
    LensTexture texture = LensTexture.none,
    List<double>? uv,
    List<double>? inverse,
  }) {
    final s = _style;
    final spec = s.spec;
    return LensDraw(
      rect: rect,
      shape: size,
      radius: _effectiveRadius,
      spec: spec,
      devicePixelRatio: _devicePixelRatio,
      reach: spec.reachOf(size, strengthOverride: s.bend, dark: false) * s.amount.clamp(0.0, 1.0),
      dispersion: s.dispersion,
      blur: texture == LensTexture.none ? 0 : s.blur,
      saturation: s.saturation,
      brightness: s.brightness,
      texture: texture,
      uv: uv,
      tint: s.tint,
      edge: s.edge,
      rim: s.rim,
      rimShine: s.rimShine,
      filterInverse: inverse,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      super.paint(context, offset);
      return;
    }
    final rect = offset & size;
    final rrect = _rrect(rect);
    paintDropShadow(context.canvas, rrect, color: _style.drop, offset: const Offset(0, 1), blur: 3);

    switch (_resolve()) {
      case GlassMode.captured:
        _clipLayer.layer = null;
        _clipRectLayer.layer = null;
        _filterLayer.layer = null;
        _paintCaptured(context.canvas, offset);
        super.paint(context, offset);
      case GlassMode.backdropFilter:
        _clipLayer.layer = null;
        _paintFiltered(context, offset);
      case GlassMode.frost:
      case GlassMode.auto:
        _clipRectLayer.layer = null;
        _paintFrosted(context, offset);
    }
  }

  void _paintCaptured(Canvas canvas, Offset offset) {
    final backdrop = _backdrop!;
    final image = backdrop.image!;
    final box = backdrop.renderBox!;
    final shader = _shader ??= GlassShaders.create();
    if (shader == null) return;
    final transform = getTransformTo(box);
    final uv = uvFor(imageRect: Offset.zero & box.size, transform: transform, localOffset: offset);
    _draw(rect: offset & size, texture: LensTexture.image, uv: uv).apply(shader, image: image);
    canvas.drawRect(offset & size, Paint()..shader = shader);
  }

  void _paintFiltered(PaintingContext context, Offset offset) {
    final shader = _filterShader ??= GlassShaders.create();
    if (shader == null) {
      _paintFrosted(context, offset);
      return;
    }
    // Local px to the backdrop texture's px: the view's, scaled to device px.
    final toGlobal = getTransformTo(null);
    final forward = Matrix4.diagonal3Values(_devicePixelRatio, _devicePixelRatio, 1)..multiply(toGlobal);
    final s = forward.storage;
    final a = s[0], b = s[4], c = s[12], d = s[1], e = s[5], f = s[13];
    final det = a * e - b * d;
    if (det.abs() < 1e-9) return;
    final inverse = <double>[e / det, -b / det, (b * f - e * c) / det, -d / det, a / det, (d * c - a * f) / det];
    _draw(rect: Offset.zero & size, texture: LensTexture.backdrop, uv: [a, b, c, d, e, f], inverse: inverse)
        .apply(shader, image: emptyImage);
    final filter = ui.ImageFilter.shader(shader);
    _clipRectLayer.layer = context.pushClipRect(
      true,
      offset,
      Offset.zero & size,
      (context, offset) {
        final layer = _filterLayer.layer ??= BackdropFilterLayer();
        layer.filter = filter;
        context.pushLayer(layer, super.paint, offset);
      },
      oldLayer: _clipRectLayer.layer,
    );
  }

  void _paintFrosted(PaintingContext context, Offset offset) {
    final local = _rrect(Offset.zero & size);
    final filter = frostFilter(sigma: _style.blur, saturation: _style.saturation, brightness: _style.brightness);
    _clipLayer.layer = context.pushClipRRect(
      true,
      offset,
      Offset.zero & size,
      local,
      (context, offset) {
        final layer = _filterLayer.layer ??= BackdropFilterLayer();
        layer.filter = filter;
        context.pushLayer(layer, (context, offset) {
          _paintOverlay(context.canvas, offset);
          super.paint(context, offset);
        }, offset);
      },
      oldLayer: _clipLayer.layer,
    );
  }

  // The tint and the lit rim alone, over a frosted backdrop.
  void _paintOverlay(Canvas canvas, Offset offset) {
    final shader = _shader ??= GlassShaders.create();
    final rect = offset & size;
    if (shader == null) {
      canvas.drawRRect(_rrect(rect), Paint()..color = _style.tint);
      if (_style.edge.a > 0) {
        canvas.drawRRect(
          _rrect(rect).deflate(0.25),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = _style.edge,
        );
      }
      return;
    }
    _draw(rect: rect).apply(shader, image: emptyImage);
    canvas.drawRect(rect, Paint()..shader = shader);
  }
}

/// The widget for [RenderLiquidGlass].
class LiquidGlassBox extends SingleChildRenderObjectWidget {
  const LiquidGlassBox({
    super.key,
    required this.radius,
    required this.style,
    super.child,
  });

  /// The corners' radius; [double.infinity] for a capsule.
  final double radius;
  final GlassStyle style;

  // Glass that leaves its mode to the page takes the theme's.
  GlassStyle _style(BuildContext context) {
    if (style.mode != GlassMode.auto) return style;
    final mode = GlassTheme.of(context).mode;
    if (mode == GlassMode.auto) return style;
    return GlassStyle(
      tint: style.tint,
      edge: style.edge,
      drop: style.drop,
      rimShine: style.rimShine,
      blur: style.blur,
      saturation: style.saturation,
      brightness: style.brightness,
      bend: style.bend,
      dispersion: style.dispersion,
      spec: style.spec,
      rim: style.rim,
      amount: style.amount,
      mode: mode,
    );
  }

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) => RenderLiquidGlass(
        radius: radius,
        style: _style(context),
        devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
        backdrop: GlassBackdrop.maybeOf(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderLiquidGlass renderObject) {
    renderObject
      ..radius = radius
      ..style = _style(context)
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1
      ..backdrop = GlassBackdrop.maybeOf(context);
  }
}

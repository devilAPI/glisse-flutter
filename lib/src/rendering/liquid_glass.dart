import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
  /// Creates a glass style from its colours, frost and lens.
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
    this.magnification = 1,
    this.magnifyOffset = Offset.zero,
  });

  /// Where the magnified spot lies from the glass's middle, in local px.
  final Offset magnifyOffset;

  /// The frost laid over what the glass shows.
  final Color tint;

  /// The colour of the 0.5px line round the glass's edge.
  final Color edge;

  /// The colour of the glass's small drop shadow.
  final Color drop;

  /// How bright the painted rim is.
  final double rimShine;

  /// The frost's blur, a deviation in logical px.
  final double blur;

  /// How much the glass saturates what it shows; 1 for no change.
  final double saturation;

  /// How much the glass brightens what it shows; 1 for no change.
  final double brightness;

  /// The lens's strength, overriding [spec]'s.
  final double bend;

  /// How much further red bends than blue, as [LensSpec.dispersion].
  final double dispersion;

  /// How the lens bends.
  final LensSpec spec;

  /// The rim painted over the glass.
  final LensRim rim;

  /// How far the glass bends now, from 0 to 1.
  final double amount;

  /// How the glass reads what's behind it.
  final GlassMode mode;

  /// How much the glass magnifies what's under its middle; 1 for none.
  final double magnification;

  /// A copy with the given fields replaced.
  GlassStyle copyWith({
    Color? tint,
    Color? edge,
    Color? drop,
    double? rimShine,
    double? blur,
    double? saturation,
    double? brightness,
    double? bend,
    double? dispersion,
    LensSpec? spec,
    LensRim? rim,
    double? amount,
    GlassMode? mode,
    double? magnification,
    Offset? magnifyOffset,
  }) {
    return GlassStyle(
      tint: tint ?? this.tint,
      edge: edge ?? this.edge,
      drop: drop ?? this.drop,
      rimShine: rimShine ?? this.rimShine,
      blur: blur ?? this.blur,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      bend: bend ?? this.bend,
      dispersion: dispersion ?? this.dispersion,
      spec: spec ?? this.spec,
      rim: rim ?? this.rim,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      magnification: magnification ?? this.magnification,
      magnifyOffset: magnifyOffset ?? this.magnifyOffset,
    );
  }

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
      other.mode == mode &&
      other.magnification == magnification &&
      other.magnifyOffset == magnifyOffset;

  @override
  int get hashCode => Object.hash(
    tint,
    edge,
    drop,
    rimShine,
    blur,
    saturation,
    brightness,
    bend,
    dispersion,
    spec,
    rim,
    amount,
    mode,
    magnification,
    magnifyOffset,
  );
}

/// The render object behind every piece of Glisse glass: a rounded
/// rectangle that bends, frosts, tints and lights what's behind it, then
/// paints its child.
class RenderLiquidGlass extends RenderProxyBox {
  /// Creates glass with corners of [radius], drawn in [style] at [devicePixelRatio].
  RenderLiquidGlass({
    required double radius,
    required GlassStyle style,
    required double devicePixelRatio,
    GlassBackdropController? backdrop,
    bool dark = false,
    GlassQuality quality = GlassQuality.high,
    RenderBox? child,
  }) : _radius = radius,
       _style = style,
       _devicePixelRatio = devicePixelRatio,
       _backdrop = backdrop,
       _dark = dark,
       _quality = quality,
       super(child);

  double _radius;

  /// The corners' radius, in logical px.
  double get radius => _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  GlassStyle _style;

  /// How the glass looks.
  GlassStyle get style => _style;
  set style(GlassStyle value) {
    if (value == _style) return;
    final relisten = attached && _wantsCopy(value.mode) != _wantsCopy(_style.mode);
    if (relisten) _unlisten();
    _style = value;
    if (relisten) _listen();
    markNeedsPaint();
  }

  bool _dark;

  GlassQuality _quality;

  /// How much work the glass does; see [GlassQuality].
  set quality(GlassQuality value) {
    if (value == _quality) return;
    _quality = value;
    markNeedsPaint();
  }

  /// Whether the glass is on a dark page, where its lens may bend by its
  /// spec's [LensSpec.darkStrength].
  set dark(bool value) {
    if (value == _dark) return;
    _dark = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  /// Device pixels per logical pixel.
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  GlassBackdropController? _backdrop;

  /// The [GlassBackdrop] copy to bend, if there is one.
  set backdrop(GlassBackdropController? value) {
    if (value == _backdrop) return;
    if (attached) _unlisten();
    _backdrop = value;
    if (attached) _listen();
    markNeedsPaint();
  }

  GlassStyle? _outer;
  GlassMode? _lastMode;

  /// The glass this glass sits in, if any.
  set outer(GlassStyle? value) {
    if (value == _outer) return;
    _outer = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  ui.FragmentShader? _filterShader;
  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<BackdropFilterLayer> _filterLayer = LayerHandle<BackdropFilterLayer>();

  GlassBackdropController? _listening;
  bool _using = false;

  // Only glass that may bend the copy asks the backdrop to take one.
  static bool _wantsCopy(GlassMode mode) => mode == GlassMode.auto || mode == GlassMode.captured;

  void _listen() {
    final backdrop = _backdrop;
    if (backdrop == null || !backdrop.isActive) return;
    backdrop.addListener(markNeedsPaint);
    _using = _wantsCopy(_style.mode);
    if (_using) backdrop.addUser();
    _listening = backdrop;
  }

  void _unlisten() {
    final backdrop = _listening;
    final using = _using;
    _listening = null;
    _using = false;
    if (backdrop == null || !backdrop.isActive) return;
    backdrop.removeListener(markNeedsPaint);
    if (using) backdrop.removeUser();
  }

  void _onShaderReady() => markNeedsPaint();

  // Where the glass was, against what it reads, when it last painted. Glass
  // can move without painting again, as in a scrolling list or a route
  // transition, where only a layer above it moves; after each frame it
  // checks, and paints again if it has moved.
  Matrix4? _paintedTransform;
  bool _watching = false;

  Matrix4? _currentTransform() {
    switch (_lastMode) {
      case GlassMode.captured:
        final box = _backdrop?.renderBox;
        if (box == null || !box.attached) return null;
        return getTransformTo(box);
      case GlassMode.backdropFilter:
        return getTransformTo(null);
      case GlassMode.frost:
      case GlassMode.auto:
      case null:
        return null;
    }
  }

  void _watch() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback(_check);
  }

  void _check(Duration _) {
    _watching = false;
    final painted = _paintedTransform;
    if (!attached || painted == null) return;
    final now = _currentTransform();
    if (now == null) return;
    var moved = false;
    for (var i = 0; i < 16; i++) {
      if ((now.storage[i] - painted.storage[i]).abs() > 1e-3) {
        moved = true;
        break;
      }
    }
    if (moved) markNeedsPaint();
    _watch();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    GlassShaders.ready.addListener(_onShaderReady);
    GlassShaders.load();
    _listen();
  }

  @override
  void detach() {
    _paintedTransform = null;
    GlassShaders.ready.removeListener(_onShaderReady);
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
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

  // The layer of the nearest glass around this one that filters the live
  // backdrop: Impeller binds that layer, not the view, as this glass's
  // backdrop. In the view's device px.
  Rect? _outerLayerRect() {
    for (var node = parent; node != null; node = node.parent) {
      // Frosted glass pushes a backdrop filter too, so it is as much a layer
      // of its own as glass that bends the live backdrop.
      if (node is RenderLiquidGlass &&
          (node._lastMode == GlassMode.backdropFilter || node._lastMode == GlassMode.frost) &&
          node.hasSize) {
        final box = MatrixUtils.transformRect(node.getTransformTo(null), Offset.zero & node.size);
        return Rect.fromLTRB(
          box.left * _devicePixelRatio,
          box.top * _devicePixelRatio,
          box.right * _devicePixelRatio,
          box.bottom * _devicePixelRatio,
        );
      }
    }
    return null;
  }

  // The size, in device px, of the view this glass is in: the backdrop
  // Impeller binds when no glass around this one filters it.
  Size get _screenSize {
    for (RenderObject? node = this; node != null; node = node.parent) {
      if (node is RenderView) return node.flutterView.physicalSize;
    }
    return ui.PlatformDispatcher.instance.implicitView?.physicalSize ?? Size.zero;
  }

  LensDraw _draw({
    required Rect rect,
    LensTexture texture = LensTexture.none,
    List<double>? uv,
    List<double>? inverse,
    Rect? outerBackdrop,
    bool preFrosted = false,
  }) {
    final s = _style;
    final spec = s.spec;
    final outer = texture == LensTexture.image ? _outer : null;
    // A copy already frosted needs no more.
    final blur = preFrosted ? 0.0 : _frostOver(texture);
    final tint = outer == null ? s.tint : Color.alphaBlend(s.tint, outer.tint);
    final saturation = outer == null ? s.saturation : s.saturation * outer.saturation;
    return LensDraw(
      rect: rect,
      shape: size,
      radius: _effectiveRadius,
      spec: spec,
      devicePixelRatio: _devicePixelRatio,
      reach: spec.reachOf(size, strengthOverride: s.bend, dark: _dark) * s.amount.clamp(0.0, 1.0),
      dispersion: s.dispersion,
      blur: texture == LensTexture.none ? 0 : blur,
      saturation: saturation,
      brightness: s.brightness,
      texture: texture,
      uv: uv,
      tint: tint,
      edge: s.edge,
      rim: s.rim,
      rimShine: s.rimShine,
      filterInverse: inverse,
      magnification: s.magnification,
      magnifyOffset: s.magnifyOffset,
      outerBackdrop: outerBackdrop,
      screenSize: texture == LensTexture.backdrop ? _screenSize : Size.zero,
      quality: _quality,
    );
  }

  // How much the glass frosts what it shows. Over a copy, glass in other
  // glass sees through that glass's frost too.
  double _frostOver(LensTexture texture) {
    final s = _style;
    final outer = texture == LensTexture.image ? _outer : null;
    return outer == null ? s.blur : math.sqrt(s.blur * s.blur + outer.blur * outer.blur);
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

    final mode = _resolve();
    _lastMode = mode;
    _paintedTransform = null;
    switch (mode) {
      case GlassMode.captured:
        _clipLayer.layer = null;
        _filterLayer.layer = null;
        _paintCaptured(context.canvas, offset);
        super.paint(context, offset);
      case GlassMode.backdropFilter:
        _paintFiltered(context, offset);
      case GlassMode.frost:
      case GlassMode.auto:
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
    _paintedTransform = transform;
    _watch();
    final uv = uvFor(imageRect: Offset.zero & box.size, transform: transform, localOffset: offset);
    // The backdrop's frosted copy, shared by all glass that frosts as much:
    // one sample a pixel here instead of dozens.
    final frosted = backdrop.frosted(_frostOver(LensTexture.image));
    _draw(
      rect: offset & size,
      texture: LensTexture.image,
      uv: uv,
      preFrosted: frosted != null && !identical(frosted, image),
    ).apply(shader, image: frosted ?? image);
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
    _paintedTransform = toGlobal;
    _watch();
    final forward = Matrix4.diagonal3Values(_devicePixelRatio, _devicePixelRatio, 1)..multiply(toGlobal);
    final s = forward.storage;
    final a = s[0], b = s[4], c = s[12], d = s[1], e = s[5], f = s[13];
    final det = a * e - b * d;
    if (det.abs() < 1e-9) {
      // Squashed flat: nothing to bend, but the child still paints.
      _clipLayer.layer = null;
      _filterLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final inverse = <double>[e / det, -b / det, (b * f - e * c) / det, -d / det, a / det, (d * c - a * f) / det];
    _draw(
      rect: Offset.zero & size,
      texture: LensTexture.backdrop,
      uv: [a, b, c, d, e, f],
      inverse: inverse,
      outerBackdrop: _outerLayerRect(),
    ).apply(shader, image: emptyImage);
    final filter = ui.ImageFilter.shader(shader);
    // Clipped to the glass's shape, so glass whose backdrop it can't place
    // (see the shader) still keeps its shape.
    _clipLayer.layer = context.pushClipRRect(true, offset, Offset.zero & size, _rrect(Offset.zero & size), (
      context,
      offset,
    ) {
      final layer = _filterLayer.layer ??= BackdropFilterLayer();
      layer.filter = filter;
      context.pushLayer(layer, super.paint, offset);
    }, oldLayer: _clipLayer.layer);
  }

  void _paintFrosted(PaintingContext context, Offset offset) {
    if (kIsWeb && _quality != GlassQuality.high) {
      // In the browser, a backdrop blur per pane is ruinous: CanvasKit blurs
      // the page again for each one, and Firefox took a quarter of a second
      // a frame over the gallery. Below high quality, glass with no copy to
      // bend there lays its tint and lit rim over the page unblurred.
      // Still clipped to its shape, as the other ways glass paints are.
      _filterLayer.layer = null;
      _clipLayer.layer = context.pushClipRRect(true, offset, Offset.zero & size, _rrect(Offset.zero & size), (
        context,
        offset,
      ) {
        _paintOverlay(context.canvas, offset);
        super.paint(context, offset);
      }, oldLayer: _clipLayer.layer);
      return;
    }
    final local = _rrect(Offset.zero & size);
    final filter = frostFilter(sigma: _style.blur, saturation: _style.saturation, brightness: _style.brightness);
    _clipLayer.layer = context.pushClipRRect(true, offset, Offset.zero & size, local, (context, offset) {
      final layer = _filterLayer.layer ??= BackdropFilterLayer();
      layer.filter = filter;
      context.pushLayer(layer, (context, offset) {
        _paintOverlay(context.canvas, offset);
        super.paint(context, offset);
      }, offset);
    }, oldLayer: _clipLayer.layer);
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
///
/// Glass inside other glass that reads a [GlassBackdrop]'s copy sees the
/// copy, not the glass around it, so it takes on the outer glass's frost and
/// tint too, and looks as it would through it.
class LiquidGlassBox extends StatelessWidget {
  /// Draws glass of [radius] in [style] behind [child].
  const LiquidGlassBox({super.key, required this.radius, required this.style, this.child});

  /// The corners' radius; [double.infinity] for a capsule.
  final double radius;

  /// How the glass looks.
  final GlassStyle style;

  /// What the glass holds, painted over it.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveStyle(context, style);
    return _LiquidGlassRender(
      radius: radius,
      style: resolved,
      // Glass paints again whenever it moves over its backdrop, as in a
      // scrolling list; its content, behind a boundary of its own, doesn't.
      child: _GlassAncestor(
        style: resolved,
        child: child == null ? const SizedBox.shrink() : RepaintBoundary(child: child),
      ),
    );
  }
}

// Glass that leaves its mode to the page takes the theme's.
GlassStyle _resolveStyle(BuildContext context, GlassStyle style) {
  if (style.mode != GlassMode.auto) return style;
  final mode = GlassTheme.of(context).mode;
  if (mode == GlassMode.auto) return style;
  return style.copyWith(mode: mode);
}

class _GlassAncestor extends InheritedWidget {
  const _GlassAncestor({required this.style, required super.child});

  final GlassStyle style;

  @override
  bool updateShouldNotify(_GlassAncestor oldWidget) => style != oldWidget.style;
}

class _LiquidGlassRender extends SingleChildRenderObjectWidget {
  const _LiquidGlassRender({required this.radius, required this.style, super.child});

  final double radius;
  final GlassStyle style;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) => RenderLiquidGlass(
    radius: radius,
    style: style,
    devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    backdrop: GlassBackdrop.maybeOf(context),
    dark: GlassTheme.of(context).isDark,
    quality: GlassTheme.of(context).effectiveQuality,
  )..outer = context.dependOnInheritedWidgetOfExactType<_GlassAncestor>()?.style;

  @override
  void updateRenderObject(BuildContext context, RenderLiquidGlass renderObject) {
    renderObject
      ..radius = radius
      ..style = style
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1
      ..backdrop = GlassBackdrop.maybeOf(context)
      ..dark = GlassTheme.of(context).isDark
      ..quality = GlassTheme.of(context).effectiveQuality
      ..outer = context.dependOnInheritedWidgetOfExactType<_GlassAncestor>()?.style;
  }
}

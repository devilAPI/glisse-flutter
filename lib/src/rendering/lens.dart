import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../foundation/theme.dart' show GlassQuality;
import 'readback.dart';

/// How a lens bends what's under it, as Glisse's `LensOptions`.
@immutable
class LensSpec {
  /// Creates a lens that bends by [strength] over a band [depth] wide.
  const LensSpec({
    required this.strength,
    required this.dispersion,
    required this.depth,
    this.dome = 0,
    this.splay = 1,
    this.relative = false,
    this.bezel = false,
    this.maxDepth,
    this.ink = false,
    this.blur = 0,
    this.paintsLight = false,
    this.darkStrength,
  });

  /// How far in the rim reaches for what it shows: a share of the bezel's
  /// width for a [bezel], else of the lens's shorter side.
  final double strength;

  /// How much further red bends than blue: at 1, a fifth further.
  final double dispersion;

  /// The width of the band round the rim that bends, in px, or a share of
  /// the shorter side when [relative].
  final double depth;

  /// The sag of the dome whose slope sets the bend along the rim.
  final double dome;

  /// How far the bend near each side keeps to that side's own direction.
  final double splay;

  /// Whether [depth] is a share of the lens's shorter side rather than px.
  final bool relative;

  /// Bends as light does through a rounded bezel: straight in from the rim,
  /// most at the very edge, by Snell's law over a squircle's slope.
  final bool bezel;

  /// The most [depth] comes to, in px, when it is relative.
  final double? maxDepth;

  /// Whether the content is ink, such as labels, whose colours fringe.
  final bool ink;

  /// Softens what the rim bends, as iOS's tab bar lens does.
  final double blur;

  /// Carried over from Glisse's lens options, where it marks a lens that
  /// paints its own rim light. Nothing reads it yet: the shader always
  /// lights the rim from the draw's [LensLight].
  final bool paintsLight;

  /// The strength on a dark page, if it differs.
  final double? darkStrength;

  /// Glass's own lens: a bezel three tenths of its shorter side wide, 36px at
  /// most, reaching as far in again as the band is wide.
  static const LensSpec glass = LensSpec(
    strength: 2,
    dispersion: 0.6,
    depth: 0.3,
    maxDepth: 36,
    relative: true,
    bezel: true,
    paintsLight: true,
  );

  /// A switch's lifted thumb, after Aave's switch.
  static const LensSpec switchThumb = LensSpec(strength: 0.45, dispersion: 1, depth: 2, dome: 6, splay: 0.4);

  /// A slider's lifted thumb, after Aave's slider.
  static const LensSpec sliderThumb = LensSpec(strength: 0.75, dispersion: 0.65, depth: 2, dome: 5, splay: 0.5);

  /// A tab bar's lifted selection, as iOS 26.1's tab bar lens.
  static const LensSpec tab = LensSpec(strength: 0.2, dispersion: 2, depth: 4, ink: true, blur: 2);

  /// A segmented control's lifted selection, after Aave's toggle group.
  static const LensSpec segment = LensSpec(strength: 0.3, dispersion: 0.1, depth: 2.5);

  /// The width of the band that bends, for a lens of [size].
  double depthOf(Size size) {
    final d = depth * (relative ? math.min(size.width, size.height) : 1);
    return maxDepth == null ? d : math.min(d, maxDepth!);
  }

  /// How far the rim reaches, in px, for a lens of [size].
  double reachOf(Size size, {double? strengthOverride, required bool dark}) {
    final own = dark ? (darkStrength ?? strength) : strength;
    final s = strengthOverride ?? own;
    return s * (bezel ? depthOf(size) : math.min(size.width, size.height));
  }

  @override
  bool operator ==(Object other) =>
      other is LensSpec &&
      other.strength == strength &&
      other.dispersion == dispersion &&
      other.depth == depth &&
      other.dome == dome &&
      other.splay == splay &&
      other.relative == relative &&
      other.bezel == bezel &&
      other.maxDepth == maxDepth &&
      other.ink == ink &&
      other.blur == blur &&
      other.paintsLight == paintsLight &&
      other.darkStrength == darkStrength;

  @override
  int get hashCode => Object.hash(
    strength,
    dispersion,
    depth,
    dome,
    splay,
    relative,
    bezel,
    maxDepth,
    ink,
    blur,
    paintsLight,
    darkStrength,
  );

  /// A copy with the given [strength], [dispersion] or [blur] replaced.
  LensSpec copyWith({double? strength, double? dispersion, double? blur}) => LensSpec(
    strength: strength ?? this.strength,
    dispersion: dispersion ?? this.dispersion,
    depth: depth,
    dome: dome,
    splay: splay,
    relative: relative,
    bezel: bezel,
    maxDepth: maxDepth,
    ink: ink,
    blur: blur ?? this.blur,
    paintsLight: paintsLight,
    darkStrength: darkStrength,
  );
}

/// Where the light catches a lens's rim.
@immutable
class LensLight {
  /// Creates a light from where it shines and how its glow and edge look.
  const LensLight({
    required this.angle,
    required this.glow,
    required this.spread,
    required this.glowPower,
    required this.edge,
    required this.edgeWidth,
    required this.edgePower,
  });

  /// The direction the light comes from, in degrees.
  final double angle;

  /// How bright the glow on the lit side of the rim is.
  final double glow;

  /// How far round the rim the glow spreads.
  final double spread;

  /// How sharply the glow falls off: higher keeps it nearer its peak.
  final double glowPower;

  /// How bright the thin lit line at the very edge is.
  final double edge;

  /// The width of that edge line, in px.
  final double edgeWidth;

  /// How sharply the edge line falls off: higher keeps it nearer its peak.
  final double edgePower;

  /// Aave's light for dark surroundings.
  static const LensLight dark = LensLight(
    angle: 45,
    glow: 0.4,
    spread: 0.5,
    glowPower: 1.5,
    edge: 0.5,
    edgeWidth: 2,
    edgePower: 1.5,
  );

  /// Aave's light for light surroundings.
  static const LensLight light = LensLight(
    angle: 30,
    glow: 0.4,
    spread: 0.5,
    glowPower: 2,
    edge: 0.5,
    edgeWidth: 1.5,
    edgePower: 1,
  );
}

/// What texture a lens draw samples.
enum LensTexture {
  /// Nothing: only the tint and rim.
  none,

  /// An image, through an affine map from local px.
  image,

  /// Impeller's live backdrop, bound by the engine.
  backdrop,
}

/// The rim a lens paints over itself.
enum LensRim {
  /// No rim.
  none,

  /// Glass's rim: a lit line at the very edge over its 0.5px edge line.
  glass,

  /// A lifted selection's chromatic rim.
  selection,

  /// A lifted selection's brighter rim, for a light page.
  brightSelection,
}

/// The circular arc that sags by `sag` across `half`, scaled so its slope
/// averages a half over that span.
({double radius, double scale}) _arc(double sag, double half) {
  final radius = (half * half + sag * sag) / (2 * sag);
  var sum = 0.0;
  for (var i = 0; i <= 200; i++) {
    final x = (i / 200) * half;
    final slope = x / math.sqrt(math.max(1e-9, radius * radius - x * x));
    sum += i == 0 || i == 200 ? slope / 2 : slope;
  }
  final mean = sum / 200;
  return (radius: radius, scale: mean > 0 ? 0.5 / mean : 1);
}

final Map<(double, double), ({double radius, double scale})> _arcs = {};

// Keyed to a hundredth of a px, and bounded, so a lens whose size animates
// doesn't grow the memo frame by frame.
({double radius, double scale}) _cachedArc(double sag, double half) {
  final key = ((sag * 100).roundToDouble() / 100, (half * 100).roundToDouble() / 100);
  final hit = _arcs[key];
  if (hit != null) return hit;
  if (_arcs.length >= 256) _arcs.clear();
  return _arcs[key] = _arc(key.$1, key.$2);
}

/// Loads and holds Glisse's shader. Widgets draw a fallback until it's ready.
class GlassShaders {
  GlassShaders._();

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  /// Whether the shader has loaded.
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  static Object? _error;

  /// The compiled program, once loaded.
  static ui.FragmentProgram? get program => usable ? _program : null;

  /// Why loading failed, if it did.
  static Object? get error => _error;

  /// Loads the shader. Safe to call any number of times; after a failure,
  /// the next call tries again.
  static Future<ui.FragmentProgram?> load() {
    if (_program != null) return Future<ui.FragmentProgram?>.value(_program);
    return _loading ??= Future.wait<Object>([_fromAssets(), _decodeEmpty()]).then(
      (loaded) {
        final program = loaded[0] as ui.FragmentProgram;
        _empty ??= loaded[1] as ui.Image;
        _program = program;
        _error = null;
        ready.value = true;
        return program;
      },
      onError: (Object error, StackTrace stack) {
        _error = error;
        _loading = null;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'glisse_flutter',
            context: ErrorDescription('while loading the Liquid Glass shader'),
          ),
        );
        return null;
      },
    );
  }

  // An app finds the package's asset under packages/glisse_flutter; the package's
  // own tests find it at its plain path. If neither loads, the error is the
  // package path's, which is the one an app has.
  static Future<ui.FragmentProgram> _fromAssets() async {
    try {
      return await ui.FragmentProgram.fromAsset('packages/glisse_flutter/shaders/glass.frag');
    } catch (error, stack) {
      try {
        return await ui.FragmentProgram.fromAsset('shaders/glass.frag');
      } catch (_) {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }

  /// Loads the shader before the first frame, so glass refracts from the
  /// start. Optional: glass loads it on its own and frosts until then.
  static Future<void> precache() async {
    final program = await load();
    if (program != null && canRecordImages) _warmUp(program);
  }

  /// Whether glass may record pictures into images: for a backdrop's copy,
  /// and for a control's lens over its own content. False only in a browser
  /// that blocks reading canvases back, such as Firefox or LibreWolf with
  /// `privacy.resistFingerprinting`, where CanvasKit fails inside
  /// `toImageSync` and breaks every draw after it. There, glass frosts with
  /// the browser's own blur, and controls lift without their lens.
  static bool get canRecordImages => debugCanRecordImagesOverride ?? (usable && canReadPixelsBack);

  /// Whether glass may use its shader at all. False only in a browser
  /// without WebGL, where Flutter draws on the CPU and the shader would take
  /// seconds a frame; glass paints as a plain tint and rim there.
  static bool get usable => debugUsableOverride ?? hasGpu;

  /// Overrides [usable], for tests.
  @visibleForTesting
  static bool? debugUsableOverride;

  /// Overrides [canRecordImages], for tests.
  @visibleForTesting
  static bool? debugCanRecordImagesOverride;

  // The clear 1x1 image a draw that samples nothing binds, decoded from bytes
  // rather than drawn, as reading a drawing back isn't possible everywhere.
  static Future<ui.Image> _decodeEmpty() {
    if (_empty != null) return Future<ui.Image>.value(_empty);
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(Uint8List(4), 1, 1, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  // Draws the shader once off screen, in each texture mode, so its pipeline
  // is compiled before the first frame that shows glass rather than during it.
  static void _warmUp(ui.FragmentProgram program) {
    try {
      final shader = program.fragmentShader();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final texture in [LensTexture.none, LensTexture.image]) {
        LensDraw(
          rect: const Rect.fromLTWH(0, 0, 8, 8),
          shape: const Size(8, 8),
          radius: 4,
          spec: LensSpec.glass,
          devicePixelRatio: 1,
          reach: 2,
          blur: 1,
          texture: texture,
          uv: const [1 / 8, 0, 0, 0, 1 / 8, 0],
          rim: LensRim.glass,
          rimShine: 0.3,
        ).apply(shader, image: emptyImage);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..shader = shader);
      }
      final picture = recorder.endRecording();
      picture.toImageSync(8, 8).dispose();
      picture.dispose();
      shader.dispose();
    } catch (_) {
      // Warming up is only an optimisation.
    }
  }

  /// A new shader from the loaded program, or null while it is still loading
  /// (this starts the load).
  static ui.FragmentShader? create() {
    if (!usable) return null;
    if (_program == null) {
      unawaited(load());
      return null;
    }
    return _program!.fragmentShader();
  }
}

/// Everything one draw of the lens shader needs.
class LensDraw {
  /// Describes one draw of [spec] over [rect], at [devicePixelRatio].
  LensDraw({
    required this.rect,
    required this.shape,
    required this.radius,
    required this.spec,
    required this.devicePixelRatio,
    this.reach = 0,
    this.dispersion,
    this.blur = 0,
    this.saturation = 1,
    this.brightness = 1,
    this.texture = LensTexture.none,
    this.uv,
    this.clearOutside = false,
    this.shine = 0,
    this.light = LensLight.dark,
    this.inkPage,
    this.tint = const Color(0x00000000),
    this.edge = const Color(0x00000000),
    this.rim = LensRim.none,
    this.rimShine = 0,
    this.rimOpacity = 1,
    this.filterInverse,
    this.textureSize = Size.zero,
    this.softensBend = false,
    this.magnification = 1,
    this.outerBackdrop,
    this.screenSize = Size.zero,
    this.magnifyOffset = Offset.zero,
    this.quality = GlassQuality.high,
  });

  /// How much work the draw does: the frost's rings, and at
  /// [GlassQuality.low] no colour split.
  final GlassQuality quality;

  /// Where the magnified spot lies from the lens's middle, in local px: a
  /// loupe held above a finger shows what's under the finger.
  final Offset magnifyOffset;

  /// For [LensTexture.backdrop]: the layer of the glass this glass sits in,
  /// in the view's device px, which Impeller binds as the backdrop instead
  /// of the view's.
  final Rect? outerBackdrop;

  /// For [LensTexture.backdrop]: the view's size in device px.
  final Size screenSize;

  /// How much the lens magnifies what's under its middle; 1 for none.
  final double magnification;

  /// Blurs only what the rim bends, as far as it bends it, rather than all
  /// the glass shows: iOS's tab bar lens.
  final bool softensBend;

  /// The lens as placed, in local px.
  final Rect rect;

  /// The lens's own size, which its map is drawn for and stretched over [rect].
  final Size shape;

  /// The corner radius of [shape], in local px.
  final double radius;

  /// How the lens bends.
  final LensSpec spec;

  /// Device pixels per logical pixel.
  final double devicePixelRatio;

  /// How far the rim reaches, in local px.
  final double reach;

  /// Overrides [LensSpec.dispersion] of [spec] when set.
  final double? dispersion;

  /// The frost's deviation, in local px.
  final double blur;

  /// How much the lens saturates what it shows; 1 for no change.
  final double saturation;

  /// How much the lens brightens what it shows; 1 for no change.
  final double brightness;

  /// What the lens samples.
  final LensTexture texture;

  /// Local px to texture uv, as (a, b, c, d, e, f): u = a x + b y + c, v = d x + e y + f.
  /// For [LensTexture.backdrop], to the texture's px instead.
  final List<double>? uv;

  /// Whether outside the image is clear, rather than its edge stretched.
  final bool clearOutside;

  /// The light caught on the rim: above 0 it brightens, below it darkens.
  final double shine;

  /// Where the light catches the rim.
  final LensLight light;

  /// For ink: the page under it, light or dark.
  final Brightness? inkPage;

  /// The colour laid over what the lens shows.
  final Color tint;

  /// The colour of the 0.5px line round the lens's edge.
  final Color edge;

  /// The rim painted over the lens.
  final LensRim rim;

  /// How bright the painted [rim] is.
  final double rimShine;

  /// How opaque the painted [rim] is, from 0 to 1.
  final double rimOpacity;

  /// For [LensTexture.backdrop]: from the backdrop texture's px to local px,
  /// as (a, b, c, d, e, f). [uv] then maps local px to the texture's px.
  final List<double>? filterInverse;

  /// The sampled texture's size, in its own px.
  final Size textureSize;

  /// This draw over an image mapped by [uv], clear outside the image: how a
  /// control's lens bends its own recorded content. What only a live
  /// backdrop needs is left unset.
  LensDraw onImage(List<double> uv) => LensDraw(
    rect: rect,
    shape: shape,
    radius: radius,
    spec: spec,
    devicePixelRatio: devicePixelRatio,
    reach: reach,
    dispersion: dispersion,
    blur: blur,
    saturation: saturation,
    brightness: brightness,
    texture: LensTexture.image,
    uv: uv,
    clearOutside: true,
    shine: shine,
    light: light,
    inkPage: inkPage,
    tint: tint,
    edge: edge,
    rim: rim,
    rimShine: rimShine,
    rimOpacity: rimOpacity,
    softensBend: softensBend,
    magnification: magnification,
    magnifyOffset: magnifyOffset,
    quality: quality,
  );

  static double _premul(Color c, double channel) => channel * c.a;

  /// Writes the uniforms, in the order glass.frag declares them.
  void apply(ui.FragmentShader shader, {ui.Image? image}) {
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);

    final w = shape.width;
    final h = shape.height;
    final halfW = w / 2;
    final halfH = h / 2;
    final r = radius.clamp(0.0, math.min(halfW, halfH)).toDouble();
    final depth = spec.depthOf(shape);

    // uSize
    f(textureSize.width);
    f(textureSize.height);
    // uRect
    f(rect.left);
    f(rect.top);
    f(math.max(rect.width, 0.0001));
    f(math.max(rect.height, 0.0001));
    // uShape
    f(w);
    f(h);
    f(r);
    f(depth);
    // uBend
    f(reach);
    f(quality == GlassQuality.low ? 0 : (dispersion ?? spec.dispersion));
    f(spec.bezel ? 1 : 0);
    f(spec.splay);
    // uDome
    final dome = spec.dome * (spec.relative ? math.min(w, h) : 1);
    if (dome > 0 && !spec.bezel) {
      final sag = math.max(0.01, math.min(dome, math.min(halfW, halfH) - 1));
      final across = _cachedArc(sag, halfW);
      final down = _cachedArc(sag, halfH);
      f(across.radius);
      f(across.scale);
      f(down.radius);
      f(down.scale);
    } else {
      f(0);
      f(0);
      f(0);
      f(0);
    }
    // uUvX, uUvY
    final m = uv ?? const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    f(m[0]);
    f(m[1]);
    f(m[2]);
    f(clearOutside ? 1 : 0);
    f(m[3]);
    f(m[4]);
    f(m[5]);
    f(switch (quality) {
      GlassQuality.low => 1,
      GlassQuality.medium => 2,
      GlassQuality.high || GlassQuality.auto => 3,
    });
    // uFrost
    f(blur);
    f(saturation);
    f(brightness);
    f(texture.index.toDouble());
    // uLightA
    final angle = light.angle * math.pi / 180;
    f(shine);
    f(math.cos(angle));
    f(math.sin(angle));
    f(light.glow);
    // uLightB
    f(light.spread);
    f(light.glowPower);
    f(light.edge);
    f(light.edgeWidth);
    // uLightC
    f(light.edgePower);
    f(!spec.ink || inkPage == null ? 0.0 : (inkPage == Brightness.light ? 1.0 : 2.0));
    f(softensBend ? 1 : 0);
    f(1 / devicePixelRatio);
    // uTint
    f(_premul(tint, tint.r));
    f(_premul(tint, tint.g));
    f(_premul(tint, tint.b));
    f(tint.a);
    // uEdge
    f(_premul(edge, edge.r));
    f(_premul(edge, edge.g));
    f(_premul(edge, edge.b));
    f(edge.a);
    // uRim
    f(rim.index.toDouble());
    f(rimShine);
    f(rimOpacity);
    f(magnification);
    // uFilter, uFilterY
    final inverse = filterInverse ?? const [1.0, 0.0, 0.0, 0.0, 1.0, 0.0];
    f(inverse[0]);
    f(inverse[1]);
    f(inverse[2]);
    f(texture == LensTexture.backdrop ? 1 : 0);
    f(inverse[3]);
    f(inverse[4]);
    f(inverse[5]);
    f(0);
    // uOuter, uScreen
    final outer = outerBackdrop;
    f(outer?.left ?? 0);
    f(outer?.top ?? 0);
    f(outer?.width ?? 0);
    f(outer?.height ?? 0);
    f(screenSize.width);
    f(screenSize.height);
    f(magnifyOffset.dx);
    f(magnifyOffset.dy);

    if (image != null) shader.setImageSampler(0, image);
  }
}

/// A 1x1 clear image, bound when a draw samples nothing (every sampler must
/// be bound).
ui.Image get emptyImage =>
    _empty ??= () {
      // Loaded with the shader, which is needed before any draw that binds
      // this; drawing it is the fallback where a draw comes first.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder);
      return recorder.endRecording().toImageSync(1, 1);
    }();
ui.Image? _empty;

/// The affine map from local px to the uv of an image covering [imageRect]
/// (in local px), after [transform] from local px into the image's space.
List<double> uvFor({required Rect imageRect, Matrix4? transform, Offset localOffset = Offset.zero}) {
  // p_image = T * (p - localOffset)
  double a = 1, b = 0, c = 0, d = 0, e = 1, f = 0;
  if (transform != null) {
    final s = transform.storage;
    a = s[0];
    b = s[4];
    c = s[12];
    d = s[1];
    e = s[5];
    f = s[13];
  }
  final ox = localOffset.dx;
  final oy = localOffset.dy;
  c = c - a * ox - b * oy;
  f = f - d * ox - e * oy;
  final w = imageRect.width == 0 ? 1.0 : imageRect.width;
  final h = imageRect.height == 0 ? 1.0 : imageRect.height;
  return [a / w, b / w, (c - imageRect.left) / w, d / h, e / h, (f - imageRect.top) / h];
}

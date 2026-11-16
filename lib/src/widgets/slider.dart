import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/content_lens.dart';
import '../rendering/hit_padding.dart';
import '../rendering/lens.dart';
import '../rendering/shadows.dart';
import 'thumb_frost.dart';

// Sizes from Glisse's slider.
const double _height = 40;
const double _trackTop = 17;
const double _trackHeight = 6;
const double _thumbWidth = 60;
const double _thumbHeight = 40;
// The thumb's centre travels from 18px in at either end.
const double _inset = 18;

/// A slider, as iOS 26's: a white knob on a rail that, held, lifts into a
/// glass lens showing the track thicker, as if magnified, bent at its rim.
class GlassSlider extends StatefulWidget {
  /// Creates a slider at [value], from [min] to [max].
  const GlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(divisions == null || divisions > 0);

  /// The current value, from [min] to [max].
  final double value;

  /// Called as the value changes. Null disables the slider.
  final ValueChanged<double>? onChanged;

  /// The value at the left end of the rail.
  final double min;

  /// The value at the right end of the rail.
  final double max;

  /// Snaps the value to this many equal steps, if set.
  final int? divisions;

  /// Called when the knob is first held, with the value as it stands.
  final ValueChanged<double>? onChangeStart;

  /// Called when the knob is let go, with the value as it stands.
  final ValueChanged<double>? onChangeEnd;

  /// The fill's colour. Defaults to the theme's accent.
  final Color? activeColor;

  /// Names the control for assistive technology.
  final String? semanticLabel;

  /// Takes keyboard focus; made for it if null.
  final FocusNode? focusNode;

  /// Whether it takes focus when first built.
  final bool autofocus;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider> with TickerProviderStateMixin {
  late final GlassSpring _lift = GlassSpring(vsync: this, stiffness: 2000, damping: 80);
  late final Listenable _repaint = Listenable.merge([_lift, GlassShaders.ready]);

  ui.FragmentShader? _shader;
  bool _focused = false;
  bool _dragging = false;
  double _width = 0;

  bool get _enabled => widget.onChanged != null && widget.max > widget.min;

  double get _progress {
    if (widget.max <= widget.min) return 0;
    return ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    GlassShaders.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lift.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _dragging = false;
      _lift.set(0);
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    _shader?.dispose();
    super.dispose();
  }

  double _snap(double progress) {
    progress = progress.clamp(0.0, 1.0);
    final divisions = widget.divisions;
    if (divisions != null) progress = (progress * divisions).round() / divisions;
    return widget.min + progress * (widget.max - widget.min);
  }

  double _valueAt(double x) {
    final travel = math.max(1.0, _width - 2 * _inset);
    return _snap((x - _inset) / travel);
  }

  void _emit(double value) {
    if (value != widget.value) widget.onChanged?.call(value);
  }

  void _down(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton) return;
    _lift.set(1);
  }

  void _up(PointerEvent event) {
    if (!_dragging) _lift.set(0);
  }

  void _tapUp(TapUpDetails details) {
    if (!_enabled) return;
    final value = _valueAt(details.localPosition.dx);
    widget.onChangeStart?.call(widget.value);
    _emit(value);
    widget.onChangeEnd?.call(value);
    _lift.set(0);
  }

  void _dragStart(DragStartDetails details) {
    if (!_enabled) return;
    _dragging = true;
    _lift.set(1);
    widget.onChangeStart?.call(widget.value);
    _emit(_valueAt(details.localPosition.dx));
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _emit(_valueAt(details.localPosition.dx));
  }

  void _dragEnd([DragEndDetails? details]) {
    if (!_dragging) return;
    _dragging = false;
    _lift.set(0);
    widget.onChangeEnd?.call(widget.value);
  }

  double get _step => widget.divisions != null ? 1 / widget.divisions! : 1 / 20;

  void _nudge(double steps) {
    if (!_enabled) return;
    final value = _snap(_progress + steps * _step);
    widget.onChangeStart?.call(widget.value);
    _emit(value);
    widget.onChangeEnd?.call(value);
  }

  void _jump(double progress) {
    if (!_enabled) return;
    final value = _snap(progress);
    widget.onChangeStart?.call(widget.value);
    _emit(value);
    widget.onChangeEnd?.call(value);
  }

  String _percent(double progress) => '${(progress.clamp(0.0, 1.0) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    Widget result = LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 200.0;
      _width = width;
      final paint = CustomPaint(
        size: Size(width, _height),
        painter: _SliderPainter(
          state: this,
          theme: theme,
          progress: _progress,
          activeColor: widget.activeColor ?? theme.fill,
          devicePixelRatio: dpr,
          focused: _focused,
          repaint: _repaint,
        ),
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // The page under the lifted thumb, frosted, under its lens.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _repaint,
              builder: (context, _) {
                final lift = _lift.value;
                if (lift <= 0.01) return const SizedBox.shrink();
                final travel = math.max(0.0, width - 2 * _inset) * _progress;
                final thumb = Rect.fromLTWH(travel - 12, 0, _thumbWidth, _thumbHeight);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [ThumbFrost(rect: scaleAbout(thumb, 0.6 + 0.4 * lift), lift: lift)],
                );
              },
            ),
          ),
          paint,
        ],
      );
    });
    result = SizedBox(height: _height, child: result);
    result = Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The slider describes itself, with increase and decrease.
        excludeFromSemantics: true,
        onTapUp: _enabled ? _tapUp : null,
        onHorizontalDragStart: _enabled ? _dragStart : null,
        onHorizontalDragUpdate: _enabled ? _dragUpdate : null,
        onHorizontalDragEnd: _enabled ? _dragEnd : null,
        onHorizontalDragCancel: _enabled ? _dragEnd : null,
        child: result,
      ),
    );
    // The thumb hangs 12px past either end of the track.
    result = HitPadding(padding: const EdgeInsets.symmetric(horizontal: 12), child: result);
    result = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _NudgeIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _NudgeIntent(-1),
        SingleActivator(LogicalKeyboardKey.pageUp): _NudgeIntent(5),
        SingleActivator(LogicalKeyboardKey.pageDown): _NudgeIntent(-5),
        SingleActivator(LogicalKeyboardKey.home): _JumpIntent(0),
        SingleActivator(LogicalKeyboardKey.end): _JumpIntent(1),
      },
      actions: <Type, Action<Intent>>{
        _NudgeIntent: CallbackAction<_NudgeIntent>(onInvoke: (intent) {
          _nudge(intent.steps);
          return null;
        }),
        _JumpIntent: CallbackAction<_JumpIntent>(onInvoke: (intent) {
          _jump(intent.progress);
          return null;
        }),
      },
      child: result,
    );
    final progress = _progress;
    return Semantics(
      slider: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: _percent(progress),
      increasedValue: _percent(progress + _step),
      decreasedValue: _percent(progress - _step),
      onIncrease: _enabled ? () => _nudge(1) : null,
      onDecrease: _enabled ? () => _nudge(-1) : null,
      child: Opacity(opacity: _enabled ? 1 : 0.35, child: result),
    );
  }
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.steps);

  final double steps;
}

class _JumpIntent extends Intent {
  const _JumpIntent(this.progress);

  final double progress;
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.state,
    required this.theme,
    required this.progress,
    required this.activeColor,
    required this.devicePixelRatio,
    required this.focused,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _GlassSliderState state;
  final GlassThemeData theme;
  final double progress;
  final Color activeColor;
  final double devicePixelRatio;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final travel = math.max(0.0, width - 2 * _inset) * progress;
    final lift = state._lift.value;
    final lifted = lift.clamp(0.0, 1.0);
    final scale = 0.6 + 0.4 * lift;
    final thumb = Rect.fromLTWH(travel - 12, 0, _thumbWidth, _thumbHeight);
    final lens = scaleAbout(thumb, scale);
    final lensRRect = roundedRect(lens, double.infinity);
    final shader = state._shader ??= GlassShaders.create();
    final lensing = lift > 0.01 && shader != null;

    // The rail, and the fill ending under the middle of the thumb, rounded
    // rather than clipped by the rail.
    void paintTrack(Canvas canvas) {
      final rail = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _trackTop, width, _trackHeight),
        const Radius.circular(_trackHeight / 2),
      );
      canvas.drawRRect(rail, Paint()..color = theme.rail);
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _trackTop, math.min(width, travel + _inset), _trackHeight),
        const Radius.circular(_trackHeight / 2),
      );
      canvas.drawRRect(fill, Paint()..color = activeColor);
    }

    if (lensing) {
      canvas.saveLayer(Rect.fromLTWH(-20, -20, width + 40, size.height + 40), Paint());
      paintTrack(canvas);
      cutOut(canvas, lensRRect);
      canvas.restore();

      // What the lifted thumb shows in place of the track: the track a little
      // thicker, as if magnified, growing as the thumb does. Within a few px
      // of either end the fill gives way from the middle of the thumb to the
      // end of the track, so an empty slider shows no fill and a full one no
      // bare rail.
      final bed = Rect.fromLTRB(-16, -4, width + 16, size.height + 4);
      final line = 8 * (0.6 + 0.4 * lifted);
      final rest = math.max(0.0, width - 2 * _inset) - travel;
      final fillWidth = travel + math.min(_inset, travel * 4) + math.max(0.0, _inset - rest * 4);
      final magnifiedTrack = Rect.fromLTWH(0, 20 - line / 2, width, line);
      final magnifiedFill = Rect.fromLTWH(0, 20 - line / 2, math.min(width, fillWidth), line);
      final image = recordImage(bed.size, devicePixelRatio, (canvas) {
        canvas.translate(-bed.left, -bed.top);
        canvas.drawRRect(roundedRect(magnifiedTrack, double.infinity), Paint()..color = theme.rail);
        if (magnifiedFill.width > 0) {
          canvas.drawRRect(roundedRect(magnifiedFill, double.infinity), Paint()..color = activeColor);
        }
      });
      final settled = 1 - lifted;
      const spec = LensSpec.sliderThumb;
      final shape = thumb.size;
      final reach = spec.reachOf(shape, strengthOverride: theme.sliderBend, dark: theme.isDark) * scale;
      paintContentLens(
        canvas,
        shader,
        image: image,
        imageRect: bed,
        draw: LensDraw(
          rect: lens,
          shape: shape,
          radius: double.infinity,
          spec: spec,
          devicePixelRatio: devicePixelRatio,
          reach: reach,
          blur: 2 * settled + 0.5 * lifted,
          brightness: 1 + 0.15 * settled,
          saturation: 1.5,
          shine: theme.lensShine,
          light: theme.lensShine < 0 ? LensLight.light : LensLight.dark,
        ),
      );
      image.dispose();
    } else {
      paintTrack(canvas);
    }

    paintThumbChrome(canvas, rect: thumb, scale: scale, lift: lifted);

    if (focused) {
      canvas.drawRRect(
        roundedRect(lens, double.infinity).inflate(4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.ring,
      );
    }
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.focused != focused;
}

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

// Sizes from Glisse's switch: --lg-scale 0.375 of Aave's 160 by 67 switch.
const double _scale = 0.375;
const double _width = 160 * _scale;
const double _height = 67 * _scale;
const double _travel = 57.9 * _scale;
const double _thumbLeft = -21.95 * _scale;
const double _thumbWidth = 146 * _scale;
const double _thumbHeight = 92 * _scale;

/// An on/off switch, as iOS 26's: a white knob that, held, lifts into a glass
/// lens bending the track under its rim, and can be dragged across.
class GlassSwitch extends StatefulWidget {
  const GlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;

  /// Called with the new value. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// The track's colour when on. Defaults to the theme's green.
  final Color? activeColor;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch> with TickerProviderStateMixin {
  late final GlassSpring _position =
      GlassSpring(vsync: this, value: widget.value ? 1 : 0, stiffness: 1000, damping: 80);
  late final GlassSpring _color = GlassSpring(vsync: this, value: widget.value ? 1 : 0, stiffness: 1000, damping: 80);
  late final GlassSpring _lift = GlassSpring(vsync: this, stiffness: 2000, damping: 80);
  late final Listenable _repaint = Listenable.merge([_position, _color, _lift, GlassShaders.ready]);

  ui.FragmentShader? _shader;
  double? _dragFrom;
  double _dragDx = 0;
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    GlassShaders.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final spring in [_position, _color, _lift]) {
      spring.reduceMotion = reduce;
    }
  }

  @override
  void didUpdateWidget(GlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _dragFrom == null) _sync();
    if (!_enabled) _lift.set(0);
  }

  @override
  void dispose() {
    _position.dispose();
    _color.dispose();
    _lift.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _sync() {
    _position.set(widget.value ? 1 : 0);
    _color.set(widget.value ? 1 : 0);
  }

  void _settle(bool? next) {
    _dragFrom = null;
    _lift.set(0);
    if (next == null || next == widget.value) {
      _sync();
      return;
    }
    _position.set(next ? 1 : 0);
    _color.set(next ? 1 : 0);
    widget.onChanged?.call(next);
  }

  void _down(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton) return;
    _lift.set(1);
  }

  void _up(PointerEvent event) {
    if (_dragFrom == null) {
      _lift.set(0);
    }
  }

  void _toggle() {
    if (!_enabled) return;
    _settle(!widget.value);
  }

  void _dragStart(DragStartDetails details) {
    if (!_enabled) return;
    _dragFrom = widget.value ? 1 : 0;
    _dragDx = 0;
    _lift.set(1);
  }

  void _dragUpdate(DragUpdateDetails details) {
    final from = _dragFrom;
    if (from == null) return;
    _dragDx += details.delta.dx;
    final value = from + _dragDx / _travel;
    final overshoot = value < 0 ? value : (value > 1 ? value - 1 : 0.0);
    _position.set(value.clamp(0.0, 1.0) + overshoot / 22);
    _color.set(value > 0.5 ? 1 : 0);
  }

  void _dragEnd(DragEndDetails details) {
    final from = _dragFrom;
    if (from == null) return;
    _settle(from + _dragDx / _travel > 0.5);
  }

  void _dragCancel() {
    if (_dragFrom == null) return;
    _settle(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    Widget result = CustomPaint(
      size: const Size(_width, _height),
      painter: _SwitchPainter(
        state: this,
        theme: theme,
        activeColor: widget.activeColor ?? theme.on,
        devicePixelRatio: dpr,
        focused: _focused,
        repaint: _repaint,
      ),
    );
    result = Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled ? _toggle : null,
        onHorizontalDragStart: _enabled ? _dragStart : null,
        onHorizontalDragUpdate: _enabled ? _dragUpdate : null,
        onHorizontalDragEnd: _enabled ? _dragEnd : null,
        onHorizontalDragCancel: _enabled ? _dragCancel : null,
        child: result,
      ),
    );
    // A touch target 44px tall, as Glisse's ::before gives it.
    result =
        HitPadding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: (44 - _height) / 2), child: result);
    result = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _toggle();
          return null;
        }),
      },
      child: result,
    );
    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _toggle : null,
      child: Opacity(opacity: _enabled ? 1 : 0.35, child: result),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({
    required this.state,
    required this.theme,
    required this.activeColor,
    required this.devicePixelRatio,
    required this.focused,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _GlassSwitchState state;
  final GlassThemeData theme;
  final Color activeColor;
  final double devicePixelRatio;
  final bool focused;

  void _paintTrack(Canvas canvas, RRect rrect, double fill) {
    canvas.drawRRect(rrect, Paint()..color = theme.track);
    if (fill > 0) {
      canvas.drawRRect(rrect, Paint()..color = activeColor.withValues(alpha: activeColor.a * fill.clamp(0.0, 1.0)));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final track = roundedRect(box, double.infinity);
    final lift = state._lift.value;
    final lifted = lift.clamp(0.0, 1.0);
    final fill = state._color.value;
    final x = state._position.value * _travel;
    final scale = 0.65 + 0.25 * lift;
    final thumb = Rect.fromLTWH(_thumbLeft + x, (size.height - _thumbHeight) / 2, _thumbWidth, _thumbHeight);
    final lens = scaleAbout(thumb, scale);
    final lensRRect = roundedRect(lens, double.infinity);
    final shader = state._shader ??= GlassShaders.create();
    final lensing = lift > 0.01 && shader != null;

    if (lensing) {
      canvas.saveLayer(box.inflate(4), Paint());
      _paintTrack(canvas, track, fill);
      cutOut(canvas, lensRRect);
      canvas.restore();

      // What the lifted thumb shows in place of the track: the track a little
      // smaller, so the glass rings it, growing as the thumb does.
      final bedRect = Rect.fromLTRB(box.left - 12, box.top - 6, box.right + 12, box.bottom + 6);
      final insetWidth = (bedRect.width - 24) * (0.85 + 0.1 * lifted);
      final insetHeight = (bedRect.height - 12) * 0.75 * (0.525 + 0.45 * lifted);
      final inset = Rect.fromCenter(center: bedRect.center, width: insetWidth, height: insetHeight);
      final image = recordImage(bedRect.size, devicePixelRatio, (canvas) {
        canvas.translate(-bedRect.left, -bedRect.top);
        _paintTrack(canvas, roundedRect(inset, double.infinity), fill);
      });
      final settled = 1 - lifted;
      final spec = LensSpec.switchThumb;
      final shape = thumb.size;
      final reach = spec.reachOf(shape, strengthOverride: theme.switchBend, dark: theme.isDark) * scale;
      paintContentLens(
        canvas,
        shader,
        image: image,
        imageRect: bedRect,
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
      _paintTrack(canvas, track, fill);
    }

    paintThumbChrome(canvas, rect: thumb, scale: scale, lift: lifted);

    if (focused) {
      canvas.drawRRect(
        track.inflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.ring,
      );
    }
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.focused != focused;
}

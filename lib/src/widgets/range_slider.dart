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

// Sizes from GlassSlider.
const double _height = 40;
const double _trackTop = 17;
const double _trackHeight = 6;
const double _thumbWidth = 60;
const double _thumbHeight = 40;
const double _inset = 18;
// A knob rests at 60% of the slider's thumb and, held, grows to its full size.
const double _restScale = 0.6;

/// A range of values, from [start] to [end].
@immutable
class GlassRange {
  /// Creates a range from [start] to [end].
  const GlassRange(this.start, this.end);

  /// The low end.
  final double start;

  /// The high end.
  final double end;

  /// A copy with the given ends replaced.
  GlassRange copyWith({double? start, double? end}) => GlassRange(start ?? this.start, end ?? this.end);

  @override
  bool operator ==(Object other) => other is GlassRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'GlassRange($start, $end)';
}

/// A slider with two knobs, picking a range: white knobs on GlassSlider's
/// rail, the accent filling between them. The knobs can meet but not cross.
/// A held knob lifts into a glass lens, as GlassSlider's does.
class GlassRangeSlider extends StatefulWidget {
  /// Creates a range slider showing [values] between [min] and [max].
  const GlassRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.semanticLabel,
    this.semanticFormatter,
    this.focusNode,
    this.endFocusNode,
    this.autofocus = false,
  }) : assert(divisions == null || divisions > 0),
       assert(min <= max);

  /// The range shown; its start must not be after its end.
  final GlassRange values;

  /// Called as either knob moves. Null disables the slider.
  final ValueChanged<GlassRange>? onChanged;

  /// The value at the left end of the rail.
  final double min;

  /// The value at the right end of the rail.
  final double max;

  /// Snaps the values to this many equal steps, if set.
  final int? divisions;

  /// Called when a knob is first held, with the range as it stands.
  final ValueChanged<GlassRange>? onChangeStart;

  /// Called when a knob is let go, with the range as it stands.
  final ValueChanged<GlassRange>? onChangeEnd;

  /// The fill's colour. Defaults to the theme's accent.
  final Color? activeColor;

  /// Names the slider for assistive technology.
  final String? semanticLabel;

  /// Describes a value for assistive technology. Defaults to a percentage.
  final String Function(double value)? semanticFormatter;

  /// The start knob's focus node.
  final FocusNode? focusNode;

  /// The end knob's focus node.
  final FocusNode? endFocusNode;

  /// Focuses the start knob when first built.
  final bool autofocus;

  @override
  State<GlassRangeSlider> createState() => _GlassRangeSliderState();
}

class _GlassRangeSliderState extends State<GlassRangeSlider> with TickerProviderStateMixin {
  // How far each knob is lifted into a lens; only the held one lifts.
  late final List<GlassSpring> _lift = [
    GlassSpring(vsync: this, stiffness: 2000, damping: 80),
    GlassSpring(vsync: this, stiffness: 2000, damping: 80),
  ];
  late final Listenable _repaint = Listenable.merge([..._lift, GlassShaders.ready]);

  // Each knob's lens draws twice, the fill and the bare rail, each with its
  // own shader: knob * 2 + pass.
  final List<ui.FragmentShader?> _shaders = List<ui.FragmentShader?>.filled(4, null);
  // What a lifted knob shows, recorded once: the track bare, and with its
  // fill all the way along. Dragging only moves where one gives way to the
  // other. Both knobs show the same track, so share them.
  final ContentImageCache _railBed = ContentImageCache();
  final ContentImageCache _fillBed = ContentImageCache();

  FocusNode? _ownStartFocus;
  FocusNode? _ownEndFocus;

  // The knob under the pointer: 0 for start, 1 for end.
  int? _active;
  // The knob drawn on top: the one last moved.
  int _top = 1;
  bool _dragging = false;
  int? _focused;
  double _width = 0;
  bool _rtl = false;

  bool get _enabled => widget.onChanged != null && widget.max > widget.min;

  FocusNode get _startFocus => widget.focusNode ?? (_ownStartFocus ??= FocusNode(debugLabel: 'GlassRangeSlider start'));
  FocusNode get _endFocus => widget.endFocusNode ?? (_ownEndFocus ??= FocusNode(debugLabel: 'GlassRangeSlider end'));

  double _progressOf(double value) {
    if (widget.max <= widget.min) return 0;
    return ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  }

  double get _startProgress => _progressOf(widget.values.start);
  double get _endProgress => math.max(_startProgress, _progressOf(widget.values.end));

  double get _travel => math.max(1.0, _width - 2 * _inset);

  /// Where a knob at [progress] sits, in local px.
  double _xOf(double progress) => _inset + _travel * (_rtl ? 1 - progress : progress);

  /// The unsnapped progress under [x].
  double _progressAt(double x) {
    final raw = ((x - _inset) / _travel).clamp(0.0, 1.0);
    return _rtl ? 1 - raw : raw;
  }

  @override
  void initState() {
    super.initState();
    GlassShaders.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final spring in _lift) {
      spring.reduceMotion = reduce;
    }
  }

  @override
  void didUpdateWidget(GlassRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownStartFocus?.dispose();
      _ownStartFocus = null;
    }
    if (oldWidget.endFocusNode != widget.endFocusNode && widget.endFocusNode != null) {
      _ownEndFocus?.dispose();
      _ownEndFocus = null;
    }
    if (!_enabled) {
      _active = null;
      _dragging = false;
      _settle();
    }
  }

  @override
  void dispose() {
    for (final spring in _lift) {
      spring.dispose();
    }
    for (final shader in _shaders) {
      shader?.dispose();
    }
    _railBed.dispose();
    _fillBed.dispose();
    _ownStartFocus?.dispose();
    _ownEndFocus?.dispose();
    super.dispose();
  }

  double _snap(double progress) {
    progress = progress.clamp(0.0, 1.0);
    final divisions = widget.divisions;
    if (divisions != null) progress = (progress * divisions).round() / divisions;
    return widget.min + progress * (widget.max - widget.min);
  }

  /// [values] with [knob] moved to [value], kept from crossing the other.
  GlassRange _with(int knob, double value) {
    final values = widget.values;
    return knob == 0
        ? GlassRange(math.min(value, values.end), values.end)
        : GlassRange(values.start, math.max(value, values.start));
  }

  void _emit(GlassRange next) {
    if (next != widget.values) widget.onChanged?.call(next);
  }

  void _grab(int knob) {
    _active = knob;
    if (_top != knob) setState(() => _top = knob);
    final other = _lift[1 - knob];
    // Knobs held together lift as one until a move picks one; the picked one
    // takes over the lens where it stands, so it doesn't drop and lift again.
    if (other.target > 0 && (_xOf(_startProgress) - _xOf(_endProgress)).abs() < 0.5) {
      _lift[knob].jump(other.value, velocity: other.velocity);
      other.set(0, instant: true);
    } else {
      other.set(0);
    }
    _lift[knob].set(1);
  }

  /// Lets both knobs down.
  void _settle() {
    _lift[0].set(0);
    _lift[1].set(0);
  }

  /// Picks the knob nearer [x]; with the two together, the side [x] is on,
  /// or null when [x] is on both, for the first move to decide.
  int? _pick(double x) {
    final start = _xOf(_startProgress);
    final end = _xOf(_endProgress);
    final toStart = (x - start).abs();
    final toEnd = (x - end).abs();
    if ((start - end).abs() < 0.5) {
      final progress = _progressAt(x);
      if (progress < _startProgress - 1e-9) return 0;
      if (progress > _endProgress + 1e-9) return 1;
      return null;
    }
    return toStart <= toEnd ? 0 : 1;
  }

  void _down(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton) return;
    final knob = _pick(event.localPosition.dx);
    // Held on two knobs at once, the top one lifts until a move picks one.
    if (knob == null) {
      _active = null;
      _lift[_top].set(1);
      _lift[1 - _top].set(0);
    } else {
      _grab(knob);
    }
  }

  // Runs before a tap's callback, so leaves the knob picked for it.
  void _up(PointerEvent event) {
    if (_dragging) return;
    _settle();
  }

  /// The knob to move to [x], settling a tie by which way [x] lies.
  int? _knobFor(double x) {
    if (_active != null) return _active;
    final progress = _progressAt(x);
    // At either end only one knob can move.
    if (_startProgress <= 0 && _endProgress <= 0) {
      _grab(1);
    } else if (_startProgress >= 1 && _endProgress >= 1) {
      _grab(0);
    } else if (progress < _startProgress - 1e-9) {
      _grab(0);
    } else if (progress > _endProgress + 1e-9) {
      _grab(1);
    } else {
      return null;
    }
    return _active;
  }

  void _tapUp(TapUpDetails details) {
    if (!_enabled) return;
    final x = details.localPosition.dx;
    final knob = _active ?? _knobFor(x);
    if (knob != null) {
      final next = _with(knob, _snap(_progressAt(x)));
      widget.onChangeStart?.call(widget.values);
      _emit(next);
      widget.onChangeEnd?.call(next);
    }
    _active = null;
    _settle();
  }

  void _dragStart(DragStartDetails details) {
    if (!_enabled) return;
    _dragging = true;
    widget.onChangeStart?.call(widget.values);
    _move(details.localPosition.dx);
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _move(details.localPosition.dx);
  }

  void _move(double x) {
    final knob = _knobFor(x);
    if (knob == null) return;
    _emit(_with(knob, _snap(_progressAt(x))));
  }

  void _dragEnd([DragEndDetails? details]) {
    if (!_dragging) return;
    _dragging = false;
    _active = null;
    _settle();
    widget.onChangeEnd?.call(widget.values);
  }

  double get _step => widget.divisions != null ? 1 / widget.divisions! : 1 / 20;

  double _progressOfKnob(int knob) => knob == 0 ? _startProgress : _endProgress;

  void _nudge(int knob, double steps) {
    if (!_enabled) return;
    final next = _with(knob, _snap(_progressOfKnob(knob) + steps * _step));
    if (_top != knob) setState(() => _top = knob);
    widget.onChangeStart?.call(widget.values);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  void _jump(int knob, double progress) {
    if (!_enabled) return;
    final next = _with(knob, _snap(progress));
    widget.onChangeStart?.call(widget.values);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  String _describe(double progress) {
    progress = progress.clamp(0.0, 1.0);
    final format = widget.semanticFormatter;
    if (format != null) return format(widget.min + progress * (widget.max - widget.min));
    return '${(progress * 100).round()}%';
  }

  /// What a knob would show one step further, kept from crossing the other.
  double _steppedProgress(int knob, double steps) {
    final next = (_progressOfKnob(knob) + steps * _step).clamp(0.0, 1.0);
    return knob == 0 ? math.min(next, _endProgress) : math.max(next, _startProgress);
  }

  Widget _knob(int knob) {
    final progress = _progressOfKnob(knob);
    final x = _xOf(progress);
    final canIncrease = _enabled && _steppedProgress(knob, 1) > progress + 1e-9;
    final canDecrease = _enabled && _steppedProgress(knob, -1) < progress - 1e-9;
    // Right moves right, whichever way the page reads.
    final forward = _rtl ? -1.0 : 1.0;
    return Positioned(
      // Keyed, so each knob keeps its focus as the draw order changes.
      key: ValueKey<int>(knob),
      left: x - _thumbWidth * _restScale / 2,
      top: 0,
      width: _thumbWidth * _restScale,
      height: _height,
      child: Semantics(
        container: true,
        slider: true,
        enabled: _enabled,
        label: knob == 0 ? 'Start' : 'End',
        value: _describe(progress),
        increasedValue: _describe(_steppedProgress(knob, 1)),
        decreasedValue: _describe(_steppedProgress(knob, -1)),
        onIncrease: canIncrease ? () => _nudge(knob, 1) : null,
        onDecrease: canDecrease ? () => _nudge(knob, -1) : null,
        child: FocusableActionDetector(
          focusNode: knob == 0 ? _startFocus : _endFocus,
          autofocus: knob == 0 && widget.autofocus,
          enabled: _enabled,
          mouseCursor: MouseCursor.defer,
          onShowFocusHighlight: (value) {
            setState(() {
              if (value) {
                _focused = knob;
                _top = knob;
              } else if (_focused == knob) {
                _focused = null;
              }
            });
          },
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(forward),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-forward),
            const SingleActivator(LogicalKeyboardKey.arrowUp): const _NudgeIntent(1),
            const SingleActivator(LogicalKeyboardKey.arrowDown): const _NudgeIntent(-1),
            const SingleActivator(LogicalKeyboardKey.pageUp): const _NudgeIntent(5),
            const SingleActivator(LogicalKeyboardKey.pageDown): const _NudgeIntent(-5),
            const SingleActivator(LogicalKeyboardKey.home): const _JumpIntent(0),
            const SingleActivator(LogicalKeyboardKey.end): const _JumpIntent(1),
          },
          actions: <Type, Action<Intent>>{
            _NudgeIntent: CallbackAction<_NudgeIntent>(
              onInvoke: (intent) {
                _nudge(knob, intent.steps);
                return null;
              },
            ),
            _JumpIntent: CallbackAction<_JumpIntent>(
              onInvoke: (intent) {
                _jump(knob, intent.progress);
                return null;
              },
            ),
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    _rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    Widget result = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 200.0;
        _width = width;
        final start = _xOf(_startProgress);
        final end = _xOf(_endProgress);
        final order = _top == 0 ? const [1, 0] : const [0, 1];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The page under a lifted knob, frosted, under its lens.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _repaint,
                builder: (context, _) {
                  final frosts = <Widget>[
                    for (final knob in order)
                      if (_lift[knob].value > 0.01)
                        ThumbFrost(
                          rect: scaleAbout(_thumbAt(knob == 0 ? start : end), 0.6 + 0.4 * _lift[knob].value),
                          lift: _lift[knob].value,
                        ),
                  ];
                  if (frosts.isEmpty) return const SizedBox.shrink();
                  return Stack(clipBehavior: Clip.none, children: frosts);
                },
              ),
            ),
            CustomPaint(
              size: Size(width, _height),
              painter: _RangePainter(
                state: this,
                theme: theme,
                start: start,
                end: end,
                top: _top,
                focused: _focused,
                activeColor: widget.activeColor ?? theme.fill,
                devicePixelRatio: dpr,
                repaint: _repaint,
              ),
            ),
            // Draw order follows the knobs, so the top one is read last.
            for (final knob in order) _knob(knob),
          ],
        );
      },
    );
    result = SizedBox(height: _height, child: result);
    result = Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Each knob describes itself, with increase and decrease.
        excludeFromSemantics: true,
        onTapUp: _enabled ? _tapUp : null,
        onHorizontalDragStart: _enabled ? _dragStart : null,
        onHorizontalDragUpdate: _enabled ? _dragUpdate : null,
        onHorizontalDragEnd: _enabled ? _dragEnd : null,
        onHorizontalDragCancel: _enabled ? _dragEnd : null,
        child: MouseRegion(cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic, child: result),
      ),
    );
    // A lifted knob hangs 12px past either end of the track.
    result = HitPadding(padding: const EdgeInsets.symmetric(horizontal: 12), child: result);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Opacity(opacity: _enabled ? 1 : 0.35, child: result),
    );
  }
}

/// The thumb of a knob whose middle is at [x], at its full, lifted size.
Rect _thumbAt(double x) => Rect.fromCenter(center: Offset(x, _height / 2), width: _thumbWidth, height: _thumbHeight);

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.steps);

  final double steps;
}

class _JumpIntent extends Intent {
  const _JumpIntent(this.progress);

  final double progress;
}

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.state,
    required this.theme,
    required this.start,
    required this.end,
    required this.top,
    required this.focused,
    required this.activeColor,
    required this.devicePixelRatio,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _GlassRangeSliderState state;
  final GlassThemeData theme;
  final double start;
  final double end;
  final int top;
  final int? focused;
  final Color activeColor;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final left = math.min(start, end);
    final right = math.max(start, end);
    final order = top == 0 ? const [1, 0] : const [0, 1];
    final lifts = [for (final spring in state._lift) spring.value];
    final lensing = [
      for (final knob in const [0, 1])
        lifts[knob] > 0.01 &&
            GlassShaders.canRecordImages &&
            (state._shaders[knob * 2] ??= GlassShaders.create()) != null,
    ];
    Rect thumbOf(int knob) => _thumbAt(knob == 0 ? start : end);
    Rect lensOf(int knob) => scaleAbout(thumbOf(knob), _restScale + (1 - _restScale) * lifts[knob]);

    // The rail, and the fill running between the knobs' middles, rounded at
    // both ends.
    void paintTrack(Canvas canvas) {
      final rail = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _trackTop, width, _trackHeight),
        const Radius.circular(_trackHeight / 2),
      );
      canvas.drawRRect(rail, Paint()..color = theme.rail);
      final fill = Rect.fromLTRB(
        left - _trackHeight / 2,
        _trackTop,
        right + _trackHeight / 2,
        _trackTop + _trackHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, const Radius.circular(_trackHeight / 2)),
        Paint()..color = activeColor,
      );
    }

    if (lensing.contains(true)) {
      canvas.saveLayer(Rect.fromLTWH(-20, -20, width + 40, size.height + 40), Paint());
      paintTrack(canvas);
      for (final knob in const [0, 1]) {
        if (lensing[knob]) cutOut(canvas, roundedRect(lensOf(knob), double.infinity));
      }
      canvas.restore();
    } else {
      paintTrack(canvas);
    }

    for (final (i, knob) in order.indexed) {
      final lift = lifts[knob];
      final lifted = lift.clamp(0.0, 1.0);
      final scale = _restScale + (1 - _restScale) * lift;
      final thumb = thumbOf(knob);
      final lens = lensOf(knob);
      if (lensing[knob]) {
        // The knob beneath, if the knobs are close, is under this one's glass.
        final other = 1 - knob;
        final beneath = i > 0 ? (Path()..addRRect(roundedRect(lensOf(other), double.infinity))) : null;
        _paintLens(canvas, size, knob: knob, thumb: thumb, lens: lens, lift: lift, scale: scale, beneath: beneath);
      }
      paintThumbChrome(canvas, rect: thumb, scale: scale, lift: lifted);
      if (focused == knob) {
        canvas.drawRRect(
          roundedRect(lens, double.infinity).inflate(4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = theme.ring,
        );
      }
    }
  }

  /// What a lifted knob shows in place of the track: the track a little
  /// thicker, as if magnified, growing as the knob does, filled between the
  /// knobs' middles as it is outside.
  ///
  /// The track is recorded once at its full thickness, bare and filled all
  /// the way, and squashed to the thickness of the moment by where the image
  /// is laid. The lens draws the filled one over the range and the bare one
  /// beyond, so a drag records nothing.
  ///
  /// [beneath], the other knob where it lies under this one, hides the track
  /// as it does outside the lens, so the lens shows the knob, not the track.
  void _paintLens(
    Canvas canvas,
    Size size, {
    required int knob,
    required Rect thumb,
    required Rect lens,
    required double lift,
    required double scale,
    Path? beneath,
  }) {
    final width = size.width;
    final lifted = lift.clamp(0.0, 1.0);
    const centre = 20.0;
    const fullLine = 8.0;
    final bed = Rect.fromLTRB(-16, -4, width + 16, size.height + 4);
    final line = fullLine * (0.6 + 0.4 * lifted);
    final key = (bed.size, devicePixelRatio, theme.rail, activeColor);
    final bar = Rect.fromLTWH(0, centre - fullLine / 2, width, fullLine);
    void paintBar(Canvas canvas, {required bool filled}) {
      canvas.translate(-bed.left, -bed.top);
      canvas.drawRRect(roundedRect(bar, double.infinity), Paint()..color = theme.rail);
      if (filled) canvas.drawRRect(roundedRect(bar, double.infinity), Paint()..color = activeColor);
    }

    final railImage = state._railBed.get(key, bed.size, devicePixelRatio, (c) => paintBar(c, filled: false));
    final fillImage = state._fillBed.get(key, bed.size, devicePixelRatio, (c) => paintBar(c, filled: true));
    final squash = line / fullLine;
    final imageRect = Rect.fromLTRB(
      bed.left,
      centre + (bed.top - centre) * squash,
      bed.right,
      centre + (bed.bottom - centre) * squash,
    );
    final settled = 1 - lifted;
    const spec = LensSpec.sliderThumb;
    final shape = thumb.size;
    final reach = spec.reachOf(shape, strengthOverride: theme.sliderBend, dark: theme.isDark) * scale;
    final draw = LensDraw(
      quality: theme.effectiveQuality,
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
    );
    // The fill runs between the knobs' middles with rounded ends, as outside
    // the lens; as the knobs meet, its ends draw in, so an empty range shows
    // no fill under a lifted knob.
    final left = math.min(start, end);
    final right = math.max(start, end);
    final cap = math.min(line / 2, right - left);
    final everywhere = lens.inflate(4);
    var filled =
        cap > 0
            ? (Path()..addRRect(
              roundedRect(
                Rect.fromLTRB(left - cap, centre - line / 2, right + cap, centre + line / 2),
                double.infinity,
              ),
            ))
            : Path();
    var bare = Path.combine(PathOperation.difference, Path()..addRect(everywhere), filled);
    if (beneath != null && beneath.getBounds().overlaps(everywhere)) {
      filled = Path.combine(PathOperation.difference, filled, beneath);
      bare = Path.combine(PathOperation.difference, bare, beneath);
    }
    canvas.save();
    canvas.clipPath(filled);
    paintContentLens(canvas, state._shaders[knob * 2]!, image: fillImage, imageRect: imageRect, draw: draw);
    canvas.restore();
    final railShader = state._shaders[knob * 2 + 1] ??= GlassShaders.create();
    if (railShader != null) {
      canvas.save();
      canvas.clipPath(bare);
      paintContentLens(canvas, railShader, image: railImage, imageRect: imageRect, draw: draw);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RangePainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.top != top ||
      oldDelegate.focused != focused ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

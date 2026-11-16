import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

// Room round each swatch for its ring when selected.
const double _pad = 6;

/// A row of round colour swatches of glass, wrapping onto more rows as
/// needed; pick one as from radio buttons. The picked one springs a little
/// larger and gets a ring round it, with a gap.
class GlassColorSwatches extends StatefulWidget {
  /// Creates colour swatches; [labels], if given, must have one per colour.
  const GlassColorSwatches({
    super.key,
    required this.colors,
    required this.value,
    required this.onChanged,
    this.size = 28,
    this.spacing = 12,
    this.labels,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(size > 0),
       assert(labels == null || labels.length == colors.length);

  /// The colours to pick from.
  final List<Color> colors;

  /// The picked colour, or null for none.
  final Color? value;

  /// Null disables the swatches.
  final ValueChanged<Color>? onChanged;

  /// Each swatch's diameter.
  final double size;

  /// About how far apart the swatches sit.
  final double spacing;

  /// What a screen reader calls each colour. Defaults to its hex code.
  final List<String>? labels;

  /// The group's label.
  final String? semanticLabel;

  /// The control's focus node, to drive or watch its focus.
  final FocusNode? focusNode;

  /// Whether it takes focus when first built.
  final bool autofocus;

  @override
  State<GlassColorSwatches> createState() => _GlassColorSwatchesState();
}

class _GlassColorSwatchesState extends State<GlassColorSwatches> {
  bool _focused = false;
  // The last index sent, so moves between rebuilds add up.
  int? _sent;

  @override
  void didUpdateWidget(GlassColorSwatches oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sent = null;
  }

  bool get _enabled => widget.onChanged != null && widget.colors.isNotEmpty;

  int get _selected => widget.value == null ? -1 : widget.colors.indexOf(widget.value!);

  void _select(int index) {
    if (!_enabled || index < 0 || index >= widget.colors.length) return;
    final color = widget.colors[index];
    if (index == (_sent ?? _selected)) return;
    _sent = index;
    widget.onChanged!(color);
  }

  void _move(int delta) {
    if (!_enabled) return;
    final count = widget.colors.length;
    final current = _sent ?? _selected;
    final next = current < 0 ? (delta > 0 ? 0 : count - 1) : (current + delta) % count;
    _select(next < 0 ? next + count : next);
  }

  String _label(int index) {
    final labels = widget.labels;
    if (labels != null) return labels[index];
    final argb = widget.colors[index].toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final selected = _selected;
    // The swatch a focus ring marks: the picked one, else the first.
    final active = selected >= 0 ? selected : 0;
    final swatches = Wrap(
      spacing: math.max(0.0, widget.spacing - 2 * _pad),
      runSpacing: math.max(0.0, widget.spacing - 2 * _pad),
      children: [
        for (var i = 0; i < widget.colors.length; i++)
          _Swatch(
            color: widget.colors[i],
            size: widget.size,
            selected: i == selected,
            focused: _focused && i == active,
            enabled: _enabled,
            label: _label(i),
            onTap: () => _select(i),
          ),
      ],
    );
    final forward = rtl ? -1 : 1;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      explicitChildNodes: true,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(forward),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-forward),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const _MoveIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _MoveIntent(-1),
          const SingleActivator(LogicalKeyboardKey.home): const _EdgeIntent(false),
          const SingleActivator(LogicalKeyboardKey.end): const _EdgeIntent(true),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MoveIntent: CallbackAction<_MoveIntent>(
              onInvoke: (intent) {
                _move(intent.delta);
                return null;
              },
            ),
            _EdgeIntent: CallbackAction<_EdgeIntent>(
              onInvoke: (intent) {
                _select(intent.end ? widget.colors.length - 1 : 0);
                return null;
              },
            ),
          },
          child: GlassFocusable(
            enabled: _enabled,
            onActivate: () => _select(active),
            radius: widget.size / 2,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            onFocusRing: (value) => setState(() => _focused = value),
            child: Opacity(opacity: _enabled ? 1 : 0.35, child: swatches),
          ),
        ),
      ),
    );
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);

  final int delta;
}

class _EdgeIntent extends Intent {
  const _EdgeIntent(this.end);

  final bool end;
}

class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.color,
    required this.size,
    required this.selected,
    required this.focused,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final double size;
  final bool selected;
  final bool focused;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> with TickerProviderStateMixin {
  // Underdamped, so the picked swatch pops past its size and settles.
  late final GlassSpring _grow = GlassSpring(vsync: this, value: _on, stiffness: 520, damping: 20);
  late final GlassSpring _ring = GlassSpring(vsync: this, value: _on, stiffness: 700, damping: 48);
  late final Listenable _motion = Listenable.merge([_grow, _ring]);

  double get _on => widget.selected ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _grow.reduceMotion = reduce;
    _ring.reduceMotion = reduce;
  }

  @override
  void didUpdateWidget(_Swatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _grow.set(_on);
      _ring.set(_on);
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final size = widget.size;
    // A ring the colour of the swatch, unless that would vanish on the page.
    final luminance = widget.color.computeLuminance();
    final faint = widget.color.a < 0.5 || (theme.isDark ? luminance < 0.02 : luminance > 0.85);
    final ringColor = faint ? theme.ring : widget.color.withValues(alpha: 1);

    final disc = LiquidGlassBox(
      radius: double.infinity,
      style: themedGlass(theme, tint: widget.color),
      child: SizedBox.square(dimension: size),
    );
    Widget swatch = AnimatedBuilder(
      animation: _motion,
      child: disc,
      builder: (context, disc) {
        final grow = _grow.value.clamp(0.0, 1.6);
        final ring = _ring.value.clamp(0.0, 1.0);
        final scale = 1 + 0.08 * grow;
        return CustomPaint(
          foregroundPainter: _RingPainter(
            radius: size * scale / 2 + 3.5 * ring,
            color: ringColor.withValues(alpha: ringColor.a * ring),
            focus: widget.focused ? theme.ring : null,
            focusRadius: size * 1.08 / 2 + 7,
          ),
          child: Center(child: Transform.scale(scale: scale, child: disc)),
        );
      },
    );
    swatch = SizedBox.square(dimension: size + 2 * _pad, child: swatch);
    swatch = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: MouseRegion(cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer, child: swatch),
    );
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled ? widget.onTap : null,
      child: swatch,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.radius, required this.color, required this.focus, required this.focusRadius});

  final double radius;
  final Color color;
  final Color? focus;
  final double focusRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (color.a > 0.001) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
    if (focus != null) {
      canvas.drawCircle(
        center,
        focusRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focus!,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.focus != focus ||
      oldDelegate.focusRadius != focusRadius;
}

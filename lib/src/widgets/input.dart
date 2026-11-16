import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../foundation/theme.dart';
import '../rendering/lens.dart';
import '../rendering/liquid_glass.dart';

/// A text field on glass, as Glisse's `Input`: a 40px capsule whose frost
/// brightens while it has focus, with an optional leading icon.
class GlassInput extends StatefulWidget {
  const GlassInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.icon,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.clearable = false,
    this.maxWidth = 360,
    this.height = 40,
    this.autocorrect = true,
    this.inputFormatters,
    this.mode = GlassMode.auto,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Shown, muted, while the field is empty.
  final String? placeholder;

  /// Shown before the text, such as a person or envelope glyph.
  final Widget? icon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Shows a clear button while there's text, as a search field does.
  final bool clearable;

  /// The widest the field grows to.
  final double maxWidth;
  final double height;
  final bool autocorrect;
  final List<TextInputFormatter>? inputFormatters;
  final GlassMode mode;

  @override
  State<GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<GlassInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(GlassInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_changed);
      _focus.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _focus.removeListener(_changed);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final focused = _focus.hasFocus;
    // The page's own font, as the input inherits it on the web.
    final style = DefaultTextStyle.of(context)
        .style
        .merge(theme.textStyle)
        .copyWith(color: theme.foreground, fontSize: 14, decoration: TextDecoration.none);
    final showClear = widget.clearable && widget.enabled && _controller.text.isNotEmpty;

    final field = CupertinoTextField.borderless(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      autocorrect: widget.autocorrect,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      placeholder: widget.placeholder,
      placeholderStyle: style.copyWith(color: theme.muted),
      style: style,
      cursorColor: theme.fill,
      padding: EdgeInsets.zero,
      maxLines: 1,
    );

    final row = Row(
      children: [
        if (widget.icon != null) ...[
          IconTheme.merge(
            data: IconThemeData(color: theme.muted, size: 16),
            child: SizedBox(width: 16, height: 16, child: Center(child: widget.icon)),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: field),
        if (showClear) ...[
          const SizedBox(width: 10),
          Transform.translate(
            offset: const Offset(8, 0),
            child: Semantics(
              button: true,
              label: 'Clear',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clear,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(child: GlassGlyph.clear(color: theme.muted, size: 14)),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    Widget glass = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: focused ? theme.glassActive : theme.glass),
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      builder: (context, color, child) => LiquidGlassBox(
        radius: widget.height / 2,
        style: GlassStyle(
          tint: color ?? theme.glass,
          edge: theme.edge,
          drop: theme.drop,
          rimShine: theme.rimShine,
          blur: theme.blur,
          saturation: theme.saturation,
          bend: theme.glassBend,
          dispersion: theme.glassDispersion,
          spec: LensSpec.glass,
          mode: widget.mode,
        ),
        child: child,
      ),
      child: SizedBox(
        height: widget.height,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: row),
      ),
    );

    glass = GestureDetector(
      // A press anywhere on the glass focuses the field.
      onTapDown: widget.enabled ? (_) => _focus.requestFocus() : null,
      child: glass,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Opacity(opacity: widget.enabled ? 1 : 0.35, child: glass),
    );
  }
}

/// A [GlassInput] for searching: a magnifier icon, a "Search" placeholder and
/// a clear button.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxWidth = 360,
    this.mode = GlassMode.auto,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final double maxWidth;
  final GlassMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return GlassInput(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      icon: GlassGlyph.magnifier(color: theme.muted, size: 16),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      autofocus: autofocus,
      clearable: true,
      maxWidth: maxWidth,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      mode: mode,
    );
  }
}

/// Glisse's own small glyphs, drawn as its SVGs are: a 16-unit box, 1.5-unit
/// round-capped strokes.
class GlassGlyph extends StatelessWidget {
  const GlassGlyph._(this._kind, {required this.color, required this.size});

  /// A magnifying glass.
  const GlassGlyph.magnifier({Key? key, required Color color, double size = 16})
      : this._(_Glyph.magnifier, color: color, size: size);

  /// A cross, for clearing.
  const GlassGlyph.clear({Key? key, required Color color, double size = 14})
      : this._(_Glyph.clear, color: color, size: size);

  /// Three dots, as a "more" button.
  const GlassGlyph.ellipsis({Key? key, required Color color, double size = 20})
      : this._(_Glyph.ellipsis, color: color, size: size);

  /// A tick.
  const GlassGlyph.check({Key? key, required Color color, double size = 16})
      : this._(_Glyph.check, color: color, size: size);

  /// A chevron pointing right.
  const GlassGlyph.chevron({Key? key, required Color color, double size = 16})
      : this._(_Glyph.chevron, color: color, size: size);

  /// A plus.
  const GlassGlyph.plus({Key? key, required Color color, double size = 16})
      : this._(_Glyph.plus, color: color, size: size);

  /// A minus.
  const GlassGlyph.minus({Key? key, required Color color, double size = 16})
      : this._(_Glyph.minus, color: color, size: size);

  final _Glyph _kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: size, child: CustomPaint(painter: _GlyphPainter(_kind, color)));
  }
}

enum _Glyph { magnifier, clear, ellipsis, check, chevron, plus, minus }

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.color);

  final _Glyph kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case _Glyph.magnifier:
        canvas.drawCircle(const Offset(7, 7), 4.75, stroke);
        canvas.drawLine(const Offset(10.5, 10.5), const Offset(13.75, 13.75), stroke);
      case _Glyph.clear:
        canvas.drawLine(const Offset(4.5, 4.5), const Offset(11.5, 11.5), stroke);
        canvas.drawLine(const Offset(11.5, 4.5), const Offset(4.5, 11.5), stroke);
      case _Glyph.ellipsis:
        final fill = Paint()..color = color;
        for (final x in const [3.0, 8.0, 13.0]) {
          canvas.drawCircle(Offset(x, 8), 1.4, fill);
        }
      case _Glyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 8.5)
            ..lineTo(6.5, 11.5)
            ..lineTo(12.5, 4.5),
          stroke,
        );
      case _Glyph.chevron:
        canvas.drawPath(
          Path()
            ..moveTo(6, 3.5)
            ..lineTo(10.5, 8)
            ..lineTo(6, 12.5),
          stroke,
        );
      case _Glyph.plus:
        canvas.drawLine(const Offset(8, 3.5), const Offset(8, 12.5), stroke);
        canvas.drawLine(const Offset(3.5, 8), const Offset(12.5, 8), stroke);
      case _Glyph.minus:
        canvas.drawLine(const Offset(3.5, 8), const Offset(12.5, 8), stroke);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.color != color;
}

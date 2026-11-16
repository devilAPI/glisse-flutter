import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

const double _radius = 12;

/// A one-time-code field: a row of glass boxes, one per character, over a
/// single hidden text field. Characters pop into their boxes; the box
/// awaiting the next one is outlined. A pasted or autofilled code fills
/// every box at once.
class GlassPinField extends StatefulWidget {
  /// Creates a code field; [length] must be positive.
  const GlassPinField({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.obscure = false,
    this.error = false,
    this.enabled = true,
    this.autofocus = false,
    this.digitsOnly = true,
    this.keyboardType,
    this.boxWidth = 44,
    this.boxHeight = 52,
    this.spacing = 8,
    this.semanticLabel,
  }) : assert(length > 0);

  /// How many characters the code has.
  final int length;

  /// Holds the code. Creates its own if null.
  final TextEditingController? controller;

  /// The control's focus node, to drive or watch its focus.
  final FocusNode? focusNode;

  /// Called as the code is typed or deleted.
  final ValueChanged<String>? onChanged;

  /// Called when the last box fills.
  final ValueChanged<String>? onCompleted;

  /// Shows a dot in place of each character.
  final bool obscure;

  /// Tints the boxes with the theme's destructive colour, and shakes them
  /// when it turns on.
  final bool error;

  /// Whether it takes input.
  final bool enabled;

  /// Whether it takes focus when first built.
  final bool autofocus;

  /// Takes only the digits 0 to 9, dropping anything else typed or pasted.
  final bool digitsOnly;

  /// The keyboard to ask for; a number pad for [digitsOnly].
  final TextInputType? keyboardType;

  /// Each box's width.
  final double boxWidth;

  /// Each box's height.
  final double boxHeight;

  /// The gap between boxes.
  final double spacing;

  /// Names the field for assistive technology.
  final String? semanticLabel;

  @override
  State<GlassPinField> createState() => _GlassPinFieldState();
}

class _GlassPinFieldState extends State<GlassPinField> with TickerProviderStateMixin {
  final GlobalKey<EditableTextState> _editable = GlobalKey<EditableTextState>();
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  late List<GlassSpring> _pops = _springs(widget.length);
  // The row's sideways shift; underdamped, so it shakes when struck.
  late final GlassSpring _shake = GlassSpring(vsync: this, stiffness: 1400, damping: 20);
  bool _reduceMotion = false;
  late String _shown = _controller.text;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'GlassPinField'));

  List<GlassSpring> _springs(int count) => [
    for (var i = 0; i < count; i++)
      GlassSpring(vsync: this, value: 1, stiffness: 600, damping: 18)..reduceMotion = _reduceMotion,
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_textChanged);
    _focus.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shake.reduceMotion = _reduceMotion;
    for (final spring in _pops) {
      spring.reduceMotion = _reduceMotion;
    }
  }

  @override
  void didUpdateWidget(GlassPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_textChanged);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_textChanged);
      _shown = _controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_focusChanged);
      if (widget.focusNode != null) {
        _ownFocus?.dispose();
        _ownFocus = null;
      }
      _focus.addListener(_focusChanged);
    }
    if (oldWidget.length != widget.length) {
      for (final spring in _pops) {
        spring.dispose();
      }
      _pops = _springs(widget.length);
    }
    if (widget.error && !oldWidget.error && !_reduceMotion) _shake.jump(0, velocity: 520);
  }

  @override
  void dispose() {
    _controller.removeListener(_textChanged);
    _focus.removeListener(_focusChanged);
    _ownController?.dispose();
    _ownFocus?.dispose();
    for (final spring in _pops) {
      spring.dispose();
    }
    _shake.dispose();
    super.dispose();
  }

  void _focusChanged() {
    // A field that has never had a caret gets one, so a paste lands.
    if (_focus.hasFocus && !_controller.selection.isValid) {
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
    if (mounted) setState(() {});
  }

  void _textChanged() {
    final value = _controller.value;
    final end = value.text.length;
    // The caret stays at the end, so typing appends and backspace deletes
    // the last character.
    if (!value.selection.isCollapsed || value.selection.baseOffset != end) {
      _controller.selection = TextSelection.collapsed(offset: end);
      return;
    }
    if (value.text == _shown) return;
    final before = _shown.characters.length;
    final after = value.text.characters.length;
    if (!_reduceMotion) {
      for (var i = before; i < math.min(after, _pops.length); i++) {
        _pops[i].jump(0.4);
      }
    }
    if (mounted) setState(() => _shown = value.text);
  }

  void _edited(String text) {
    widget.onChanged?.call(text);
    if (text.characters.length == widget.length) widget.onCompleted?.call(text);
  }

  void _tap() {
    if (!widget.enabled) return;
    if (_focus.hasFocus) {
      _editable.currentState?.requestKeyboard();
    } else {
      _focus.requestFocus();
    }
  }

  Widget _box(GlassThemeData theme, int index, List<String> chars, bool focused) {
    final count = chars.length;
    final active = focused && index == math.min(count, widget.length - 1);
    final char = index < count ? chars[index] : null;
    final error = widget.error;
    final outline =
        error
            ? theme.destructive.withValues(alpha: active ? 1 : 0.7)
            : (active ? theme.ring : theme.ring.withValues(alpha: 0));
    final tint = error ? Color.alphaBlend(theme.destructive.withValues(alpha: 0.16), theme.glass) : null;
    Widget content;
    if (char == null) {
      // An empty box awaiting the next character shows the caret.
      content =
          active ? Container(width: 2, height: widget.boxHeight * 0.42, color: theme.fill) : const SizedBox.shrink();
    } else {
      final face =
          widget.obscure
              ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: theme.foreground, shape: BoxShape.circle),
              )
              : Text(
                char,
                style: DefaultTextStyle.of(context).style
                    .merge(theme.textStyle)
                    .copyWith(
                      color: error ? theme.destructive : theme.foreground,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
              );
      content = AnimatedBuilder(
        animation: _pops[index],
        builder: (context, child) => Transform.scale(scale: _pops[index].value, child: child),
        child: face,
      );
    }
    return LiquidGlassBox(
      radius: _radius,
      style: themedGlass(theme, tint: tint),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: widget.boxWidth,
        height: widget.boxHeight,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: outline, width: 2),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final focused = _focus.hasFocus && widget.enabled;
    final chars = _shown.characters.take(widget.length).toList();
    final boxes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) SizedBox(width: widget.spacing),
          _box(theme, i, chars, focused),
        ],
      ],
    );
    final field = EditableText(
      key: _editable,
      controller: _controller,
      focusNode: _focus,
      readOnly: !widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.obscure,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      // Lets a code be pasted; there are no handles or toolbar to show.
      enableInteractiveSelection: true,
      showCursor: false,
      showSelectionHandles: false,
      rendererIgnoresPointer: true,
      maxLines: 1,
      keyboardType: widget.keyboardType ?? (widget.digitsOnly ? TextInputType.number : TextInputType.text),
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [_PinFormatter(length: widget.length, digitsOnly: widget.digitsOnly)],
      onChanged: _edited,
      // The text itself is never seen: the boxes show it.
      style: const TextStyle(color: Color(0x00000000), fontSize: 1, height: 1),
      cursorColor: const Color(0x00000000),
      backgroundCursorColor: const Color(0x00000000),
    );
    Widget result = Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(child: boxes),
        Positioned.fill(
          child: Semantics(
            label: widget.semanticLabel ?? '${widget.length}-character code',
            child: ExcludeFocus(excluding: !widget.enabled, child: field),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _tap : null,
            child: MouseRegion(cursor: widget.enabled ? SystemMouseCursors.text : MouseCursor.defer),
          ),
        ),
      ],
    );
    result = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(offset: Offset(_shake.value, 0), child: child),
      child: result,
    );
    return Opacity(opacity: widget.enabled ? 1 : 0.35, child: result);
  }
}

/// Keeps a code to [length] characters, digits only if [digitsOnly], with
/// the caret at its end. Pasted into a full field, a whole code replaces it.
class _PinFormatter extends TextInputFormatter {
  _PinFormatter({required this.length, required this.digitsOnly});

  final int length;
  final bool digitsOnly;

  static final RegExp _notDigit = RegExp(r'[^0-9]');
  static final RegExp _space = RegExp(r'\s');

  String _clean(String text) => text.replaceAll(digitsOnly ? _notDigit : _space, '');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final old = _clean(oldValue.text);
    var text = _clean(newValue.text);
    if (text.characters.length > length) {
      final added = text.startsWith(old) ? text.substring(old.length) : '';
      text =
          added.characters.length >= length
              ? added.characters.take(length).toString()
              : text.characters.take(length).toString();
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

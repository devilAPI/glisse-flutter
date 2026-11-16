import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'button.dart';
import 'control_utils.dart';
import 'pressable.dart';

/// A padded panel of glass: an optional header row of [leading], [title]
/// over [subtitle], and [trailing], above a [child].
///
/// With an [onTap] the whole card is a button: it presses like glass, lights
/// up under the pointer, and takes keyboard focus. It fills the width it's
/// given, so give it a bounded one.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.mode = GlassMode.auto,
  });

  /// Shown before the title, such as an icon at 24px.
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;

  /// Shown at the end of the header, such as a value or a chevron.
  final Widget? trailing;

  /// The body, under the header.
  final Widget? child;

  /// Makes the card a button.
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  /// The frost's colour. Defaults to the theme's glass.
  final Color? tint;

  /// Names the card for assistive technology, in place of its text.
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final GlassMode mode;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _tappable => widget.onTap != null;

  Widget? _header(GlassThemeData theme, TextStyle base) {
    final hasText = widget.title != null || widget.subtitle != null;
    if (!hasText && widget.leading == null && widget.trailing == null) return null;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          DefaultTextStyle(
            style: base.copyWith(color: theme.foreground, fontSize: 17, fontWeight: FontWeight.w600, height: 1.25),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: widget.title!,
          ),
        if (widget.subtitle != null)
          Padding(
            padding: EdgeInsets.only(top: widget.title != null ? 2 : 0),
            child: DefaultTextStyle(
              style: base.copyWith(color: theme.muted, fontSize: 13, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              child: widget.subtitle!,
            ),
          ),
      ],
    );
    return Row(
      children: [
        if (widget.leading != null) ...[
          IconTheme.merge(data: IconThemeData(color: theme.fill, size: 24), child: widget.leading!),
          const SizedBox(width: 12),
        ],
        Expanded(child: text),
        if (widget.trailing != null) ...[
          const SizedBox(width: 10),
          DefaultTextStyle(
            style: base.copyWith(color: theme.muted, fontSize: 15),
            child: IconTheme.merge(data: IconThemeData(color: theme.muted, size: 20), child: widget.trailing!),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final header = _header(theme, base);
    final radius = widget.borderRadius;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header,
        if (header != null && widget.child != null) const SizedBox(height: 12),
        if (widget.child != null)
          DefaultTextStyle(
            style: base.copyWith(color: theme.foreground, fontSize: 14, height: 1.35),
            child: widget.child!,
          ),
      ],
    );
    content = Padding(padding: widget.padding, child: content);
    content = IconTheme.merge(data: IconThemeData(color: theme.foreground, size: 20), child: content);

    final rest = widget.tint ?? theme.glass;
    final tint = _tappable && (_pressed || _hovered) ? Color.lerp(rest, theme.glassActive, 0.7)! : rest;
    Widget card = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      // Lights up at once when pressed, and fades on release.
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.ease,
      builder: (context, color, child) => LiquidGlassBox(
        radius: radius,
        style: themedGlass(theme, tint: color ?? tint).copyWith(mode: widget.mode),
        child: child,
      ),
      child: _tappable ? GlassPressableGlow(radius: radius, child: content) : content,
    );

    if (!_tappable) {
      return Semantics(container: true, label: widget.semanticLabel, child: card);
    }

    card = GlassPressable(
      onPressChanged: (state) {
        if (state.pressed != _pressed) setState(() => _pressed = state.pressed);
      },
      child: card,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GlassFocusable(
          enabled: true,
          onActivate: widget.onTap,
          radius: radius,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: card,
          ),
        ),
      ),
    );
  }
}

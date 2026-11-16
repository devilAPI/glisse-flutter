import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';
import 'hairline.dart';
import 'input.dart';

/// A section that opens and closes: a header row with a [title] and a
/// chevron that turns to point down as the [child] grows into view below.
///
/// Give [expanded] to control it, and change it from [onExpansionChanged];
/// leave it null and the section keeps its own state, starting from
/// [initiallyExpanded].
///
/// On its own it sits on a card of glass. Set [inset] to false to put it in
/// a [GlassListSection] as one of its rows.
class GlassDisclosure extends StatefulWidget {
  /// Creates a disclosure section.
  const GlassDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.subtitle,
    this.expanded,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.inset = true,
    this.borderRadius = 26,
    this.childPadding,
    this.enabled = true,
    this.maintainState = false,
    this.focusNode,
  });

  /// The header row's main line.
  final Widget title;

  /// Shown when expanded.
  final Widget child;

  /// Sized 28px across, as a [GlassListTile]'s.
  final Widget? leading;

  /// Shown under the [title], in smaller type.
  final Widget? subtitle;

  /// Whether it's open, for a section the parent controls.
  final bool? expanded;

  /// Whether it starts open, for a section that keeps its own state.
  final bool initiallyExpanded;

  /// Called with the new state when the header is tapped.
  final ValueChanged<bool>? onExpansionChanged;

  /// Whether it sits on a card of glass of its own.
  final bool inset;

  /// The corner radius of its card; unused when [inset] is false.
  final double borderRadius;

  /// The space round [child]. Defaults to a list row's insets; pass
  /// [EdgeInsets.zero] for a child of rows.
  final EdgeInsetsGeometry? childPadding;

  /// Whether the header responds to input.
  final bool enabled;

  /// Whether to keep [child] built while it's closed.
  final bool maintainState;

  /// The control's focus node, to drive or watch its focus.
  final FocusNode? focusNode;

  @override
  State<GlassDisclosure> createState() => _GlassDisclosureState();
}

class _GlassDisclosureState extends State<GlassDisclosure> with SingleTickerProviderStateMixin {
  // 0 closed, 1 open.
  late final GlassSpring _open;
  late bool _ownExpanded = widget.initiallyExpanded;
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _expanded => widget.expanded ?? _ownExpanded;

  @override
  void initState() {
    super.initState();
    // Damped just short of critical: it settles with the barest overshoot.
    _open = GlassSpring(vsync: this, value: _expanded ? 1 : 0, stiffness: 380, damping: 35)..addListener(_moved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _open.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handed from controlled to its own state, it carries on as it was.
    if (oldWidget.expanded != null && widget.expanded == null) _ownExpanded = oldWidget.expanded!;
    _open.set(_expanded ? 1 : 0);
    // A press can't finish once disabled; no setState, as this is a build.
    if (!widget.enabled) _pressed = false;
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  // The body is dropped once it has closed, so it rebuilds as it does.
  bool _wasShowing = false;
  void _moved() {
    final showing = _open.value > 0.0001 || _expanded;
    if (showing != _wasShowing && mounted) setState(() {});
  }

  void _toggle() {
    if (!widget.enabled) return;
    final next = !_expanded;
    if (widget.expanded == null) setState(() => _ownExpanded = next);
    widget.onExpansionChanged?.call(next);
    _open.set(_expanded ? 1 : 0);
  }

  void _press(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _pressed = pressed; // Mid-build: the build under way shows it.
      return;
    }
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enabled = widget.enabled;
    final fill =
        _pressed
            ? theme.highlight
            : (_hovered || _focused) && enabled
            ? theme.highlight.withValues(alpha: theme.highlight.a * 0.6)
            : theme.highlight.withValues(alpha: 0);

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: base.copyWith(color: theme.foreground, fontSize: 16, height: 1.25),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          child: widget.title,
        ),
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DefaultTextStyle(
              style: base.copyWith(color: theme.muted, fontSize: 13, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              child: widget.subtitle!,
            ),
          ),
      ],
    );

    // Right in a left-to-right page, left in a right-to-left one; both turn
    // to point down.
    final chevron = AnimatedBuilder(
      animation: _open,
      child: Transform.flip(flipX: rtl, child: GlassGlyph.chevron(color: theme.muted, size: 14)),
      builder: (context, child) => Transform.rotate(angle: _open.value * math.pi / 2 * (rtl ? -1 : 1), child: child),
    );

    Widget header = AnimatedContainer(
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.ease,
      color: fill,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: theme.fill, size: 22),
              child: SizedBox.square(dimension: 28, child: Center(child: widget.leading)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: text),
          const SizedBox(width: 8),
          chevron,
        ],
      ),
    );
    header = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      expanded: _expanded,
      onTap: enabled ? _toggle : null,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _press(true) : null,
          onTapUp: enabled ? (_) => _press(false) : null,
          // Always set: a recognizer dropped mid-press, as when disabled,
          // cancels through the old callback during the build.
          onTapCancel: () => _press(false),
          onTap: enabled ? _toggle : null,
          child: Opacity(opacity: enabled ? 1 : 0.38, child: header),
        ),
      ),
    );

    _wasShowing = _open.value > 0.0001 || _expanded;
    final keep = _wasShowing || widget.maintainState;
    Widget? body;
    if (keep) {
      final indent = widget.leading != null ? 16.0 + 28 + 12 : 16.0;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // In a list, the body is parted from its header as rows are.
          if (!widget.inset)
            Padding(
              padding: EdgeInsetsDirectional.only(start: indent),
              child: SizedBox(height: hairline(context), child: ColoredBox(color: theme.separator)),
            ),
          Padding(
            padding:
                widget.childPadding ??
                (widget.inset
                    ? const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 14)
                    : const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 12)),
            child: DefaultTextStyle(
              style: base.copyWith(color: theme.foreground, fontSize: 14, height: 1.35),
              child: widget.child,
            ),
          ),
        ],
      );
      body = AnimatedBuilder(
        animation: _open,
        child: body,
        builder: (context, child) {
          final t = math.max(0.0, _open.value);
          final closed = t <= 0.0001 && !_expanded;
          // Growing, it fades in once there's room; shrinking, it fades first.
          return ClipRect(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              heightFactor: t,
              child: Opacity(
                opacity: Curves.easeOut.transform(((t - 0.15) / 0.85).clamp(0.0, 1.0)),
                child: ExcludeFocus(
                  excluding: !_expanded,
                  child: ExcludeSemantics(excluding: closed || !_expanded, child: child),
                ),
              ),
            ),
          );
        },
      );
      if (widget.maintainState) {
        body = Offstage(offstage: !_wasShowing, child: TickerMode(enabled: _wasShowing, child: body));
      }
    }

    Widget section = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, if (body != null) body],
    );

    if (widget.inset) {
      section = Glass(
        borderRadius: widget.borderRadius,
        child: ClipRRect(borderRadius: BorderRadius.circular(widget.borderRadius), child: section),
      );
    }
    return section;
  }
}

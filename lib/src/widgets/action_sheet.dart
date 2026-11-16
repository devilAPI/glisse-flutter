import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'glass.dart';
import 'hairline.dart';
import 'overlay_scope.dart';

/// A row of a [GlassActionSheet].
class GlassActionSheetAction {
  /// Creates a row for an action sheet.
  const GlassActionSheetAction({
    required this.child,
    this.result,
    this.onPressed,
    this.isDefault = false,
    this.destructive = false,
  });

  /// The label, usually a [Text].
  final Widget child;

  /// What `showGlassActionSheet` returns when this action is chosen.
  final Object? result;

  /// Called when chosen, after the sheet starts to close.
  final VoidCallback? onPressed;

  /// The action the sheet suggests: in bold.
  final bool isDefault;

  /// An action that deletes or can't be undone: red.
  final bool destructive;
}

/// Shows an action sheet that springs up from the bottom over a dimmed
/// page, as iOS's do: a group of [actions] under an optional [title] and
/// [message], and a [cancel] button of its own below them.
///
/// Resolves with the chosen action's `result`, or null when the sheet is
/// dismissed with a tap outside it or the Escape key.
Future<T?> showGlassActionSheet<T>({
  required BuildContext context,
  Widget? title,
  Widget? message,
  required List<GlassActionSheetAction> actions,
  GlassActionSheetAction? cancel,
  bool barrierDismissible = true,
  String semanticLabel = 'Actions',
  bool useRootNavigator = true,
}) {
  final carried = GlassOverlayContext.of(context);
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _GlassActionSheetRoute<T>(
      carried: carried,
      dismissible: barrierDismissible,
      reduceMotion: reduceMotion,
      sheet: GlassActionSheet(
        title: title,
        message: message,
        actions: actions,
        cancel: cancel,
        semanticLabel: semanticLabel,
      ),
    ),
  );
}

class _GlassActionSheetRoute<T> extends PopupRoute<T> {
  _GlassActionSheetRoute({
    required this.carried,
    required this.dismissible,
    required this.reduceMotion,
    required this.sheet,
  });

  final GlassOverlayContext carried;
  final bool dismissible;
  final bool reduceMotion;
  final GlassActionSheet sheet;

  static final Curve _rise = GlassSpringCurve(stiffness: 320, dampingRatio: 0.82, duration: 0.5);

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Color? get barrierColor => carried.theme.isDark ? const Color(0x66000000) : const Color(0x33000000);

  @override
  Duration get transitionDuration => Duration(milliseconds: reduceMotion ? 150 : 500);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: reduceMotion ? 120 : 240);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final media = MediaQuery.of(context);
    return carried.wrap(
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8 + media.viewPadding.left,
            media.padding.top + 8,
            8 + media.viewPadding.right,
            8 + media.viewPadding.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AnimatedBuilder(
              animation: animation,
              child: sheet,
              builder: (context, child) {
                final closing = animation.status == AnimationStatus.reverse;
                // A sheet on its way out takes no more taps.
                child = IgnorePointer(ignoring: closing, child: child);
                if (reduceMotion) return Opacity(opacity: animation.value, child: child);
                final t = animation.value;
                final shown = closing ? Curves.easeIn.transform(t) : _rise.transform(t);
                return FractionalTranslation(translation: Offset(0, (1 - shown) * 1.1), child: child);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// An action sheet of glass, as iOS's: a group of full-width rows parted
/// by hairlines, and a cancel button below it.
///
/// A finger lights the row under it and can slide across the rows; letting
/// go over one chooses it. Choosing pops the sheet's route with the action's
/// `result`. Usually shown with [showGlassActionSheet].
class GlassActionSheet extends StatefulWidget {
  /// Creates an action sheet.
  const GlassActionSheet({
    super.key,
    this.title,
    this.message,
    required this.actions,
    this.cancel,
    this.semanticLabel = 'Actions',
  });

  /// Shown at the top of the sheet, above [message].
  final Widget? title;

  /// Shown under the [title], in smaller type.
  final Widget? message;

  /// The rows, in order, parted by hairlines.
  final List<GlassActionSheetAction> actions;

  /// Shown on its own below the group, in bold.
  final GlassActionSheetAction? cancel;

  /// Names the sheet for assistive technology.
  final String semanticLabel;

  @override
  State<GlassActionSheet> createState() => _GlassActionSheetState();
}

const double _radius = 26;
const double _rowHeight = 56;

class _GlassActionSheetState extends State<GlassActionSheet> {
  final Map<int, GlobalKey> _rowKeys = {};
  int? _pointer;
  int? _lit;
  int? _focusVisible;
  bool _chosen = false;

  // Rows are numbered in order; the cancel button comes last.
  List<GlassActionSheetAction> get _all => [...widget.actions, if (widget.cancel != null) widget.cancel!];

  GlobalKey _rowKey(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  int? _rowAt(Offset global) {
    for (final entry in _rowKeys.entries) {
      if (entry.key >= _all.length) continue;
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final local = box.globalToLocal(global);
      if (!(Offset.zero & box.size).contains(local)) continue;
      // A row scrolled out of the group's view isn't there to touch.
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is RenderBox) {
        final view = viewport as RenderBox;
        final inView = view.globalToLocal(global);
        if (!(Offset.zero & view.size).contains(inView)) continue;
      }
      return entry.key;
    }
    return null;
  }

  void _light(int? index) {
    if (_lit != index) setState(() => _lit = index);
  }

  void _choose(int index) {
    if (_chosen || index >= _all.length) return;
    final route = ModalRoute.of(context);
    // Already on its way out: a second choice would pop the page below.
    if (route != null && !route.isCurrent) return;
    _chosen = true;
    final action = _all[index];
    Navigator.of(context).pop(action.result);
    action.onPressed?.call();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    _pointer = event.pointer;
    _light(_rowAt(event.position));
  }

  void _move(PointerEvent event) {
    if (_pointer == null) {
      if (event.kind == PointerDeviceKind.mouse) _light(_rowAt(event.position));
      return;
    }
    if (event.pointer == _pointer) _light(_rowAt(event.position));
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final row = _rowAt(event.position);
    _light(event.kind == PointerDeviceKind.mouse ? row : null);
    if (row != null) _choose(row);
  }

  void _cancelPointer([PointerEvent? event]) {
    if (event != null && event.pointer != _pointer) return;
    _pointer = null;
    _light(null);
  }

  // Scrolling a long group takes the finger: it chooses nothing.
  bool _scrolled(ScrollStartNotification notification) {
    if (notification.dragDetails != null) _cancelPointer();
    return false;
  }

  Widget _row(GlassThemeData theme, int index, GlassActionSheetAction action, {required bool cancel}) {
    final lit = _lit == index || (_focusVisible == index && _pointer == null);
    final colour = action.destructive ? theme.destructive : theme.fill;
    final weight = action.isDefault || cancel ? FontWeight.w600 : FontWeight.w400;
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: DefaultTextStyle(
            style: base.copyWith(color: colour, fontSize: 18, fontWeight: weight, height: 1.2),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: IconTheme.merge(data: IconThemeData(color: colour, size: 20), child: action.child),
          ),
        ),
      ),
    );
    row = AnimatedContainer(
      // Lights up at once under a finger, and fades when it leaves.
      duration: lit ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.ease,
      color: lit ? theme.highlight : const Color(0x00000000),
      child: row,
    );
    return Semantics(
      key: _rowKey(index),
      container: true,
      button: true,
      onTap: () => _choose(index),
      child: FocusableActionDetector(
        // The first row takes focus, so the keyboard starts in the sheet.
        autofocus: index == 0,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight:
            (shown) => setState(() {
              if (shown) {
                _focusVisible = index;
              } else if (_focusVisible == index) {
                _focusVisible = null;
              }
            }),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _choose(index);
              return null;
            },
          ),
        },
        child: row,
      ),
    );
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      node.focusInDirection(TraversalDirection.down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      node.focusInDirection(TraversalDirection.up);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final line = hairline(context);
    final rule = SizedBox(height: line, child: ColoredBox(color: theme.separator));

    final header = <Widget>[
      if (widget.title != null)
        DefaultTextStyle(
          style: base.copyWith(color: theme.muted, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
          textAlign: TextAlign.center,
          child: Semantics(header: true, child: widget.title!),
        ),
      if (widget.title != null && widget.message != null) const SizedBox(height: 4),
      if (widget.message != null)
        DefaultTextStyle(
          style: base.copyWith(color: theme.muted, fontSize: 13, height: 1.3),
          textAlign: TextAlign.center,
          child: widget.message!,
        ),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < widget.actions.length; i++) {
      if (i > 0) rows.add(rule);
      rows.add(_row(theme, i, widget.actions[i], cancel: false));
    }

    final groupChildren = <Widget>[
      if (header.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: header,
          ),
        ),
      if (header.isNotEmpty && rows.isNotEmpty) rule,
      if (rows.isNotEmpty)
        Flexible(
          child: NotificationListener<ScrollStartNotification>(
            onNotification: _scrolled,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
        ),
    ];

    Widget pane(Widget child) => GlassSurfaceShadow(
      radius: _radius,
      offset: const Offset(0, 8),
      blur: 32,
      child: Glass(
        borderRadius: _radius,
        tint: floatingTint(theme),
        blur: 5,
        child: ClipRRect(borderRadius: BorderRadius.circular(_radius), child: child),
      ),
    );

    final cancel = widget.cancel;
    final sheet = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groupChildren.isNotEmpty)
          Flexible(
            child: pane(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: groupChildren,
              ),
            ),
          ),
        if (groupChildren.isNotEmpty && cancel != null) const SizedBox(height: 8),
        if (cancel != null) pane(_row(theme, widget.actions.length, cancel, cancel: true)),
      ],
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: FocusTraversalGroup(
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _key,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerHover: _move,
            onPointerUp: _up,
            onPointerCancel: _cancelPointer,
            child: MouseRegion(
              onExit: (_) {
                if (_pointer == null) _light(null);
              },
              child: sheet,
            ),
          ),
        ),
      ),
    );
  }
}

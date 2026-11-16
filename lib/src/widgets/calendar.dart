import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'button.dart';
import 'control_utils.dart';
import 'input.dart' show GlassGlyph;

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

// By DateTime.weekday, less one: Monday first.
const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
bool _sameDay(DateTime? a, DateTime? b) =>
    a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;
bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// A month of days on glass, to pick a date from.
///
/// The header shows the month with buttons for the one before and after; a
/// sideways swipe changes month too. Today is ringed, the picked day filled
/// with the accent. Days before [firstDate] or after [lastDate] can't be
/// picked. With the keyboard, the arrows move between days and enter picks.
class GlassCalendar extends StatefulWidget {
  const GlassCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.initialMonth,
    this.firstDate,
    this.lastDate,
    this.currentDate,
    this.firstDayOfWeek = DateTime.monday,
    this.onMonthChanged,
    this.activeColor,
    this.maxWidth = 360,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday);

  /// The picked day, or null for none. Only its date counts.
  final DateTime? selectedDate;

  /// Called with the day tapped. Null makes the calendar read-only.
  final ValueChanged<DateTime>? onDateSelected;

  /// The month shown first. Defaults to the selected date's, else today's.
  final DateTime? initialMonth;

  /// The first day that can be picked, if any.
  final DateTime? firstDate;

  /// The last day that can be picked, if any.
  final DateTime? lastDate;

  /// Today. Defaults to now.
  final DateTime? currentDate;

  /// The day each week starts on, from [DateTime.monday] to [DateTime.sunday].
  final int firstDayOfWeek;

  /// Called with the first of the month whenever the month shown changes.
  final ValueChanged<DateTime>? onMonthChanged;

  /// The picked day's fill. Defaults to the theme's accent.
  final Color? activeColor;

  /// The widest the calendar grows to.
  final double maxWidth;
  final String? semanticLabel;

  /// Focuses the grid of days.
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassCalendar> createState() => _GlassCalendarState();
}

class _GlassCalendarState extends State<GlassCalendar> {
  late DateTime _month = _monthOf(widget.initialMonth ?? widget.selectedDate ?? widget.currentDate ?? DateTime.now());
  // The day the keyboard is on, and whether its ring shows.
  DateTime? _focused;
  bool _ring = false;
  // Which way the last change of month went, for the slide.
  int _slide = 0;
  double _swipe = 0;
  bool _reduceMotion = false;

  bool get _selectable => widget.onDateSelected != null;
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;
  DateTime get _today => _dayOf(widget.currentDate ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    final first = widget.firstDate;
    final last = widget.lastDate;
    assert(first == null || last == null || !last.isBefore(first), 'lastDate is before firstDate');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedDate;
    if (selected != null && !_sameDay(selected, oldWidget.selectedDate) && !_sameMonth(selected, _month)) {
      // A date picked elsewhere brings its month into view.
      _slide = _monthOf(selected).isAfter(_month) ? 1 : -1;
      _month = _monthOf(selected);
      final shown = _month;
      // Not mid-build: the listener may well set state of its own.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _month == shown) widget.onMonthChanged?.call(shown);
      });
    }
  }

  bool _allowed(DateTime day) {
    final first = widget.firstDate;
    final last = widget.lastDate;
    if (first != null && day.isBefore(_dayOf(first))) return false;
    if (last != null && day.isAfter(_dayOf(last))) return false;
    return true;
  }

  bool _canGo(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    final first = widget.firstDate;
    final last = widget.lastDate;
    if (delta < 0 && first != null) return !DateTime(target.year, target.month + 1, 0).isBefore(_dayOf(first));
    if (delta > 0 && last != null) return !target.isAfter(_dayOf(last));
    return true;
  }

  void _show(DateTime month) {
    month = _monthOf(month);
    if (_sameMonth(month, _month)) return;
    setState(() {
      _slide = month.isAfter(_month) ? 1 : -1;
      _month = month;
    });
    widget.onMonthChanged?.call(month);
  }

  void _go(int delta) {
    if (_canGo(delta)) _show(DateTime(_month.year, _month.month + delta));
  }

  void _select(DateTime day) {
    if (!_selectable || !_allowed(day)) return;
    _show(day);
    setState(() => _focused = day);
    widget.onDateSelected!(day);
  }

  // Where the keyboard starts in the month shown: the picked day, else
  // today, else the first day that can be picked.
  DateTime _anchor() {
    final selected = widget.selectedDate;
    if (selected != null && _sameMonth(selected, _month) && _allowed(_dayOf(selected))) return _dayOf(selected);
    if (_sameMonth(_today, _month) && _allowed(_today)) return _today;
    final days = _daysIn(_month.year, _month.month);
    for (var d = 1; d <= days; d++) {
      final day = DateTime(_month.year, _month.month, d);
      if (_allowed(day)) return day;
    }
    return _month;
  }

  DateTime get _cursor {
    final focused = _focused;
    return focused != null && _sameMonth(focused, _month) ? focused : _anchor();
  }

  void _moveTo(DateTime day) {
    if (!_allowed(day)) return;
    setState(() => _focused = day);
    _show(day);
  }

  void _moveDays(int days) {
    final from = _cursor;
    _moveTo(DateTime(from.year, from.month, from.day + days));
  }

  void _moveMonths(int months) {
    final from = _cursor;
    final year = from.year;
    final month = from.month + months;
    _moveTo(DateTime(year, month, math.min(from.day, _daysIn(year, month))));
  }

  void _moveInWeek(bool end) {
    final from = _cursor;
    final column = (from.weekday - widget.firstDayOfWeek + 7) % 7;
    _moveDays(end ? 6 - column : -column);
  }

  void _swipeEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final moved = velocity.abs() > 300 ? velocity : (_swipe.abs() > 40 ? _swipe : 0.0);
    _swipe = 0;
    if (moved == 0) return;
    // Swiping towards the start brings the next month.
    final towardsStart = _rtl ? moved > 0 : moved < 0;
    _go(towardsStart ? 1 : -1);
  }

  String _describe(DateTime day) => '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]} ${day.year}';

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final accent = widget.activeColor ?? theme.fill;
    final rtl = _rtl;
    final today = _today;
    final title = '${_months[_month.month - 1]} ${_month.year}';

    Widget chevron(bool back) => Transform.flip(
          // The glyph points right; back points to the start.
          flipX: back != rtl,
          child: GlassGlyph.chevron(color: theme.foreground, size: 16),
        );

    final header = Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textStyle.copyWith(
                color: theme.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        GlassButton(
          icon: chevron(true),
          height: 32,
          semanticLabel: 'Previous month',
          onPressed: _canGo(-1) ? () => _go(-1) : null,
        ),
        const SizedBox(width: 6),
        GlassButton(
          icon: chevron(false),
          height: 32,
          semanticLabel: 'Next month',
          onPressed: _canGo(1) ? () => _go(1) : null,
        ),
      ]),
    );

    final weekdays = ExcludeSemantics(
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                _weekdays[(widget.firstDayOfWeek - 1 + i) % 7][0],
                style: theme.textStyle.copyWith(color: theme.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ]),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? math.min(constraints.maxWidth, widget.maxWidth) : 320.0;
      const padding = 12.0;
      final cell = (width - 2 * padding) / 7;
      final rowHeight = math.min(cell, 44.0);
      final circle = math.min(36.0, rowHeight - 4);

      final leading = (DateTime(_month.year, _month.month).weekday - widget.firstDayOfWeek + 7) % 7;
      final focused = _ring ? _cursor : null;
      final grid = KeyedSubtree(
        key: ValueKey<int>(_month.year * 12 + _month.month),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < 6; row++)
              SizedBox(
                height: rowHeight,
                child: Row(children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(builder: (context) {
                        final day = DateTime(_month.year, _month.month, 1 - leading + row * 7 + column);
                        final allowed = _allowed(day);
                        final isToday = _sameDay(day, today);
                        return _DayCell(
                          key: ValueKey<DateTime>(day),
                          day: day.day,
                          inMonth: day.month == _month.month,
                          today: isToday,
                          selected: _sameDay(day, widget.selectedDate),
                          focused: _sameDay(day, focused),
                          enabled: allowed && _selectable,
                          diameter: circle,
                          accent: accent,
                          label: '${isToday ? 'Today, ' : ''}${_describe(day)}',
                          onTap: () => _select(day),
                        );
                      }),
                    ),
                ]),
              ),
          ],
        ),
      );

      Widget days = AnimatedSwitcher(
        duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey<int>(_month.year * 12 + _month.month);
          final from = Offset(0.3 * _slide * (incoming ? 1 : -1), 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: from, end: Offset.zero).animate(animation),
              textDirection: Directionality.of(context),
              child: child,
            ),
          );
        },
        child: grid,
      );
      days = ClipRect(child: days);
      days = GestureDetector(
        excludeFromSemantics: true,
        onHorizontalDragStart: (_) => _swipe = 0,
        onHorizontalDragUpdate: (details) => _swipe += details.delta.dx,
        onHorizontalDragEnd: _swipeEnd,
        onHorizontalDragCancel: () => _swipe = 0,
        child: days,
      );
      days = FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) => setState(() => _ring = value),
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(rtl ? 1 : -1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(rtl ? -1 : 1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _MoveIntent(-7),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const _MoveIntent(7),
          const SingleActivator(LogicalKeyboardKey.pageUp): const _MonthIntent(-1),
          const SingleActivator(LogicalKeyboardKey.pageDown): const _MonthIntent(1),
          const SingleActivator(LogicalKeyboardKey.home): const _WeekEdgeIntent(false),
          const SingleActivator(LogicalKeyboardKey.end): const _WeekEdgeIntent(true),
          const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          _MoveIntent: CallbackAction<_MoveIntent>(onInvoke: (intent) {
            _moveDays(intent.days);
            return null;
          }),
          _MonthIntent: CallbackAction<_MonthIntent>(onInvoke: (intent) {
            _moveMonths(intent.months);
            return null;
          }),
          _WeekEdgeIntent: CallbackAction<_WeekEdgeIntent>(onInvoke: (intent) {
            _moveInWeek(intent.end);
            return null;
          }),
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _select(_cursor);
            return null;
          }),
        },
        child: days,
      );

      return Semantics(
        container: true,
        label: widget.semanticLabel,
        explicitChildNodes: true,
        child: SizedBox(
          width: width,
          child: LiquidGlassBox(
            radius: 24,
            style: themedGlass(theme),
            child: Padding(
              padding: const EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [header, weekdays, const SizedBox(height: 4), days],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.days);

  final int days;
}

class _MonthIntent extends Intent {
  const _MonthIntent(this.months);

  final int months;
}

class _WeekEdgeIntent extends Intent {
  const _WeekEdgeIntent(this.end);

  final bool end;
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.focused,
    required this.enabled,
    required this.diameter,
    required this.accent,
    required this.label,
    required this.onTap,
  });

  final int day;
  final bool inMonth;
  final bool today;
  final bool selected;
  final bool focused;
  final bool enabled;
  final double diameter;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> with SingleTickerProviderStateMixin {
  // Underdamped, so the fill pops past its size and settles.
  late final GlassSpring _fill = GlassSpring(vsync: this, value: widget.selected ? 1 : 0, stiffness: 520, damping: 24);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fill.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(_DayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _fill.set(widget.selected ? 1 : 0);
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final ink = widget.today
        ? widget.accent
        : widget.inMonth
            ? theme.foreground
            : theme.muted.withValues(alpha: theme.muted.a * 0.7);
    final base = theme.textStyle.copyWith(
      fontSize: 15,
      height: 1,
      letterSpacing: -0.2,
      fontWeight: widget.today || widget.selected ? FontWeight.w600 : FontWeight.w400,
    );
    Widget cell = AnimatedBuilder(
      animation: _fill,
      builder: (context, _) {
        final fill = _fill.value;
        final t = fill.clamp(0.0, 1.0);
        return CustomPaint(
          painter: _DayPainter(
            fill: fill.clamp(0.0, 1.4),
            accent: widget.accent,
            outline: widget.today ? widget.accent.withValues(alpha: widget.accent.a * (1 - t)) : null,
            focus: widget.focused ? theme.ring : null,
            diameter: widget.diameter,
          ),
          child: Center(
            child: Text(
              '${widget.day}',
              maxLines: 1,
              style: base.copyWith(color: Color.lerp(ink, const Color(0xFFFFFFFF), t)),
            ),
          ),
        );
      },
    );
    if (!widget.enabled && !widget.selected) cell = Opacity(opacity: 0.35, child: cell);
    cell = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: MouseRegion(cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer, child: cell),
    );
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled ? widget.onTap : null,
      child: ExcludeSemantics(child: cell),
    );
  }
}

class _DayPainter extends CustomPainter {
  _DayPainter({
    required this.fill,
    required this.accent,
    required this.outline,
    required this.focus,
    required this.diameter,
  });

  final double fill;
  final Color accent;
  final Color? outline;
  final Color? focus;
  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = diameter / 2;
    if (fill > 0.001) canvas.drawCircle(center, radius * fill, Paint()..color = accent);
    final ring = Paint()..style = PaintingStyle.stroke;
    if (outline != null && outline!.a > 0.001) {
      canvas.drawCircle(
          center,
          radius - 0.75,
          ring
            ..strokeWidth = 1.5
            ..color = outline!);
    }
    if (focus != null) {
      canvas.drawCircle(
          center,
          radius + 2,
          ring
            ..strokeWidth = 2
            ..color = focus!);
    }
  }

  @override
  bool shouldRepaint(_DayPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.accent != accent ||
      oldDelegate.outline != outline ||
      oldDelegate.focus != focus ||
      oldDelegate.diameter != diameter;
}

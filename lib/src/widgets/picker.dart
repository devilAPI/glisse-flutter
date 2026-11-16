import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../rendering/liquid_glass.dart';
import 'control_utils.dart';

const double _itemExtent = 32;
const double _defaultHeight = 216;
const Duration _nudgeDuration = Duration(milliseconds: 220);

/// The English month names a [GlassDatePicker] shows.
const List<String> glassMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// An iOS wheel picker: rows on a turning drum that fade towards its edges,
/// the chosen one resting on a glass band across the middle.
///
/// Give it either [children] or [items]; [items] are shown as text.
class GlassPicker extends StatefulWidget {
  const GlassPicker({
    super.key,
    this.children,
    this.items,
    required this.onSelectedItemChanged,
    this.initialItem = 0,
    this.controller,
    this.looping = false,
    this.height = _defaultHeight,
    this.itemExtent = _itemExtent,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  })  : assert((children == null) != (items == null), 'Give either children or items.'),
        assert(itemExtent > 0);

  /// The rows, as widgets.
  final List<Widget>? children;

  /// The rows, as text.
  final List<String>? items;

  /// Called with the row that comes to rest in the middle. Null disables
  /// the picker.
  final ValueChanged<int>? onSelectedItemChanged;

  /// The row shown first, when there's no [controller].
  final int initialItem;

  /// Drives the wheel; one is made from [initialItem] if not given.
  final FixedExtentScrollController? controller;

  /// Whether the rows go round, the first following the last.
  final bool looping;
  final double height;

  /// The height of each row.
  final double itemExtent;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassPicker> createState() => _GlassPickerState();
}

class _GlassPickerState extends State<GlassPicker> {
  FixedExtentScrollController? _ownController;

  FixedExtentScrollController get _controller =>
      widget.controller ?? (_ownController ??= FixedExtentScrollController(initialItem: widget.initialItem));

  int get _count => widget.items?.length ?? widget.children!.length;

  @override
  void didUpdateWidget(GlassPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _ownController != null) {
      _ownController!.dispose();
      _ownController = null;
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final items = widget.items;
    final enabled = widget.onSelectedItemChanged != null;
    final wheel = _Wheel(
      controller: _controller,
      itemCount: _count,
      itemExtent: widget.itemExtent,
      looping: widget.looping,
      enabled: enabled,
      onSelected: (index, _) => widget.onSelectedItemChanged?.call(index),
      itemBuilder: (context, index) => items != null ? Text(items[index]) : widget.children![index],
      semanticLabel: widget.semanticLabel,
      semanticValue: (index) => items != null ? items[index] : '${index + 1} of $_count',
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
    );
    final picker = LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 200.0;
      return SizedBox(
        width: width,
        height: widget.height,
        child: Stack(
          children: [
            Positioned.fill(child: Center(child: _Band(theme: theme, height: widget.itemExtent))),
            Positioned.fill(child: wheel),
          ],
        ),
      );
    });
    return Opacity(opacity: enabled ? 1 : 0.35, child: picker);
  }
}

/// The glass capsule behind the chosen row.
class _Band extends StatelessWidget {
  const _Band({required this.theme, required this.height, this.nested = false});

  final GlassThemeData theme;
  final double height;

  /// Lies on other glass, so it frosts lighter and casts no shadow.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LiquidGlassBox(
        radius: double.infinity,
        style: themedGlass(theme, tint: nested ? theme.highlight : theme.glass, shadow: !nested),
        child: SizedBox(height: height, width: double.infinity),
      ),
    );
  }
}

/// One drum of a picker, with its own focus, keys and description.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelected,
    required this.semanticValue,
    this.itemExtent = _itemExtent,
    this.looping = false,
    this.enabled = true,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final double itemExtent;
  final bool looping;
  final bool enabled;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Called with the row now in the middle, and the wheel's raw index, which
  /// runs past the rows' count as a looping wheel goes round.
  final void Function(int index, int raw) onSelected;
  final String Function(int index) semanticValue;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late int _selected = _normalize(widget.controller.initialItem);
  late int _lastRaw = widget.controller.initialItem;
  bool _focused = false;

  int _normalize(int raw) {
    if (widget.itemCount == 0) return 0;
    return widget.looping ? raw % widget.itemCount : raw.clamp(0, widget.itemCount - 1);
  }

  @override
  void didUpdateWidget(_Wheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = widget.controller;
    _selected = _normalize(controller.hasClients ? controller.selectedItem : _selected);
    // Rows taken away from under the wheel: it comes back to the last one.
    if (!widget.looping && widget.itemCount > 0 && controller.hasClients) {
      final last = widget.itemCount - 1;
      if (controller.selectedItem > last) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.hasClients && controller.selectedItem > last) controller.jumpToItem(last);
        });
      }
    }
  }

  void _changed(int raw) {
    if (raw == _lastRaw) return;
    _lastRaw = raw;
    final index = _normalize(raw);
    if (index == _selected) {
      // A whole turn of a looping wheel still counts, for AM and PM.
      widget.onSelected(index, raw);
      return;
    }
    void apply() {
      if (!mounted) return;
      setState(() => _selected = index);
    }

    // Scrolls can report while laying out; never set state mid-build.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _selected = index;
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
    unawaited(HapticFeedback.selectionClick());
    widget.onSelected(index, raw);
  }

  bool _can(int steps) {
    if (!widget.enabled || widget.itemCount == 0) return false;
    if (widget.looping) return true;
    final next = _selected + steps;
    return next >= 0 && next < widget.itemCount;
  }

  void _nudge(int steps) {
    if (!widget.enabled || !widget.controller.hasClients || widget.itemCount == 0) return;
    final current = widget.controller.selectedItem;
    var target = current + steps;
    if (!widget.looping) target = target.clamp(0, widget.itemCount - 1);
    if (target == current) return;
    unawaited(widget.controller.animateToItem(target, duration: _nudgeDuration, curve: Curves.easeOutCubic));
  }

  void _tapRow(int raw) {
    if (!widget.enabled || !widget.controller.hasClients) return;
    if (raw == widget.controller.selectedItem) return;
    unawaited(widget.controller.animateToItem(raw, duration: _nudgeDuration * 1.4, curve: Curves.easeOutCubic));
  }

  Widget? _row(BuildContext context, int raw) {
    if (widget.itemCount == 0) return null;
    if (!widget.looping && (raw < 0 || raw >= widget.itemCount)) return null;
    return GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? () => _tapRow(raw) : null,
      child: Center(child: widget.itemBuilder(context, _normalize(raw))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    // The page's own font, as GlassInput takes it.
    final style = DefaultTextStyle.of(context).style.merge(theme.textStyle).copyWith(
          color: theme.foreground,
          fontSize: 20,
          height: 1.2,
          letterSpacing: -0.4,
          decoration: TextDecoration.none,
        );
    Widget wheel = ListWheelScrollView.useDelegate(
      controller: widget.controller,
      itemExtent: widget.itemExtent,
      diameterRatio: 1.1,
      squeeze: 1.1,
      physics: widget.enabled ? const FixedExtentScrollPhysics() : const NeverScrollableScrollPhysics(),
      onSelectedItemChanged: _changed,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.looping ? null : widget.itemCount,
        builder: _row,
      ),
    );
    // Rows fade out towards the drum's top and bottom.
    wheel = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00000000),
          Color(0x59000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x59000000),
          Color(0x00000000)
        ],
        stops: [0, 0.2, 0.42, 0.58, 0.8, 1],
      ).createShader(bounds),
      child: DefaultTextStyle(
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        child: wheel,
      ),
    );
    wheel = Stack(
      children: [
        Positioned.fill(child: ExcludeSemantics(child: wheel)),
        if (_focused)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  height: widget.itemExtent + 4,
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(side: BorderSide(color: theme.ring, width: 2)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    wheel = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.pageUp): _MoveIntent(-5),
        SingleActivator(LogicalKeyboardKey.pageDown): _MoveIntent(5),
      },
      actions: <Type, Action<Intent>>{
        _MoveIntent: CallbackAction<_MoveIntent>(onInvoke: (intent) {
          _nudge(intent.steps);
          return null;
        }),
      },
      child: wheel,
    );
    final count = widget.itemCount;
    String? valueAt(int steps) {
      if (!_can(steps)) return null;
      return widget.semanticValue((_selected + steps) % math.max(1, count));
    }

    return Semantics(
      container: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      value: count == 0 ? null : widget.semanticValue(_selected),
      increasedValue: valueAt(1),
      decreasedValue: valueAt(-1),
      onIncrease: _can(1) ? () => _nudge(1) : null,
      onDecrease: _can(-1) ? () => _nudge(-1) : null,
      child: wheel,
    );
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.steps);

  final int steps;
}

/// Wheels side by side on one pane of glass, with one band across them.
class _WheelGroup extends StatelessWidget {
  const _WheelGroup({required this.height, required this.enabled, required this.semanticLabel, required this.wheels});

  final double height;
  final bool enabled;
  final String? semanticLabel;
  final List<(double width, Widget wheel)> wheels;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    // Narrower than the wheels want, they share what there is.
    final row = LayoutBuilder(builder: (context, constraints) {
      final wanted = wheels.fold<double>(0, (sum, w) => sum + w.$1);
      final room = constraints.hasBoundedWidth ? constraints.maxWidth : wanted;
      final scale = wanted > room && wanted > 0 ? room / wanted : 1.0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (width, wheel) in wheels) SizedBox(width: width * scale, height: height, child: wheel),
        ],
      );
    });
    // Frosted as a menu is, so the rows read over a busy page.
    final surface = LiquidGlassBox(
      radius: 24,
      style: themedGlass(theme, tint: theme.surface),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Stack(
          children: [
            Positioned.fill(child: Center(child: _Band(theme: theme, height: _itemExtent, nested: true))),
            FocusTraversalGroup(child: row),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Opacity(opacity: enabled ? 1 : 0.35, child: surface),
    );
  }
}

/// How many days [month] of [year] has.
int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// An iOS date picker on glass: month, day and year wheels side by side.
/// The day keeps within the month, rolling back from the 31st to the 30th,
/// say, when the month turns to one with fewer days.
class GlassDatePicker extends StatefulWidget {
  const GlassDatePicker({
    super.key,
    this.initialDate,
    required this.onDateTimeChanged,
    this.minimumYear = 1900,
    this.maximumYear = 2100,
    this.height = _defaultHeight,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(minimumYear <= maximumYear);

  /// The date shown first; today if not given. Its time of day is kept.
  final DateTime? initialDate;

  /// Called with the date as it changes. Null disables the picker.
  final ValueChanged<DateTime>? onDateTimeChanged;
  final int minimumYear;
  final int maximumYear;
  final double height;
  final String? semanticLabel;

  /// The month wheel's focus node.
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassDatePicker> createState() => _GlassDatePickerState();
}

class _GlassDatePickerState extends State<GlassDatePicker> {
  late final DateTime _initial = widget.initialDate ?? DateTime.now();
  late int _year = _initial.year.clamp(widget.minimumYear, widget.maximumYear);
  late int _month = _initial.month;
  late int _day = math.min(_initial.day, _daysIn(_year, _month));
  late final FixedExtentScrollController _months = FixedExtentScrollController(initialItem: _month - 1);
  late final FixedExtentScrollController _days = FixedExtentScrollController(initialItem: _day - 1);
  late final FixedExtentScrollController _years = FixedExtentScrollController(initialItem: _year - widget.minimumYear);
  // What was last reported; set up front, as it's compared after changes.
  late DateTime _last;

  bool get _enabled => widget.onDateTimeChanged != null;

  @override
  void initState() {
    super.initState();
    _last = _date;
  }

  DateTime get _date => DateTime(
        _year,
        _month,
        math.min(_day, _daysIn(_year, _month)),
        _initial.hour,
        _initial.minute,
        _initial.second,
      );

  @override
  void dispose() {
    _months.dispose();
    _days.dispose();
    _years.dispose();
    super.dispose();
  }

  void _emit() {
    final date = _date;
    if (date == _last) return;
    _last = date;
    widget.onDateTimeChanged?.call(date);
  }

  void _monthChanged(int index, int raw) {
    setState(() => _month = index + 1);
    _emit();
  }

  void _dayChanged(int index, int raw) {
    setState(() => _day = index + 1);
    _emit();
  }

  void _yearChanged(int index, int raw) {
    setState(() => _year = widget.minimumYear + index);
    _emit();
  }

  /// Once the wheels stop, a day past the month's end rolls back to it.
  bool _settled(ScrollEndNotification notification) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_days.hasClients) return;
      final over = _day - _daysIn(_year, _month);
      if (over <= 0) return;
      unawaited(_days.animateToItem(_days.selectedItem - over, duration: _nudgeDuration, curve: Curves.easeOutCubic));
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final days = _daysIn(_year, _month);
    final years = widget.maximumYear - widget.minimumYear + 1;
    return NotificationListener<ScrollEndNotification>(
      onNotification: _settled,
      child: _WheelGroup(
        height: widget.height,
        enabled: _enabled,
        semanticLabel: widget.semanticLabel,
        wheels: [
          (
            124,
            _Wheel(
              controller: _months,
              itemCount: 12,
              looping: true,
              enabled: _enabled,
              onSelected: _monthChanged,
              itemBuilder: (context, index) => Text(glassMonthNames[index]),
              semanticLabel: 'Month',
              semanticValue: (index) => glassMonthNames[index],
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
            ),
          ),
          (
            56,
            _Wheel(
              controller: _days,
              itemCount: 31,
              looping: true,
              enabled: _enabled,
              onSelected: _dayChanged,
              // Days the month doesn't have show, muted, as on iOS.
              itemBuilder: (context, index) =>
                  Text('${index + 1}', style: index + 1 > days ? TextStyle(color: theme.muted) : null),
              semanticLabel: 'Day',
              semanticValue: (index) => '${math.min(index + 1, days)}',
            ),
          ),
          (
            76,
            _Wheel(
              controller: _years,
              itemCount: years,
              enabled: _enabled,
              onSelected: _yearChanged,
              itemBuilder: (context, index) => Text('${widget.minimumYear + index}'),
              semanticLabel: 'Year',
              semanticValue: (index) => '${widget.minimumYear + index}',
            ),
          ),
        ],
      ),
    );
  }
}

/// An iOS time picker on glass: hour and minute wheels, with an AM/PM
/// wheel unless [use24hFormat]. In 12-hour form, turning the hour past 12
/// turns AM to PM and back.
class GlassTimePicker extends StatefulWidget {
  const GlassTimePicker({
    super.key,
    this.initialTime,
    required this.onDateTimeChanged,
    this.use24hFormat = false,
    this.minuteInterval = 1,
    this.height = _defaultHeight,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(minuteInterval > 0 && 60 % minuteInterval == 0, 'minuteInterval must divide 60.');

  /// The time shown first; now if not given. Its date is kept.
  final DateTime? initialTime;

  /// Called with the time as it changes, on [initialTime]'s date. Null
  /// disables the picker.
  final ValueChanged<DateTime>? onDateTimeChanged;

  /// Shows hours 0 to 23 and no AM/PM wheel.
  final bool use24hFormat;

  /// The minutes the minute wheel steps by; must divide 60.
  final int minuteInterval;
  final double height;
  final String? semanticLabel;

  /// The hour wheel's focus node.
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<GlassTimePicker> createState() => _GlassTimePickerState();
}

class _GlassTimePickerState extends State<GlassTimePicker> {
  late final DateTime _initial = widget.initialTime ?? DateTime.now();
  late int _hour = _initial.hour;
  late int _minute = _initial.minute - _initial.minute % widget.minuteInterval;
  late final FixedExtentScrollController _hours =
      FixedExtentScrollController(initialItem: widget.use24hFormat ? _hour : _hour % 12);
  late final FixedExtentScrollController _minutes =
      FixedExtentScrollController(initialItem: _minute ~/ widget.minuteInterval);
  late final FixedExtentScrollController _periods = FixedExtentScrollController(initialItem: _hour >= 12 ? 1 : 0);
  // Which turn of twelve the hour wheel is on, to flip AM and PM between.
  late int _turn = _hours.initialItem ~/ 12;
  // What was last reported; set up front, as it's compared after changes.
  late DateTime _last;

  bool get _enabled => widget.onDateTimeChanged != null;
  bool get _pm => _hour >= 12;

  @override
  void initState() {
    super.initState();
    _last = _time;
  }

  DateTime get _time => DateTime(_initial.year, _initial.month, _initial.day, _hour, _minute);

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _periods.dispose();
    super.dispose();
  }

  void _emit() {
    final time = _time;
    if (time == _last) return;
    _last = time;
    widget.onDateTimeChanged?.call(time);
  }

  void _hourChanged(int index, int raw) {
    if (widget.use24hFormat) {
      setState(() => _hour = index);
    } else {
      // Index 0 is 12 o'clock: passing it, either way, flips the half-day.
      final turn = (raw / 12).floor();
      var pm = _pm;
      if ((turn - _turn).isOdd) {
        pm = !pm;
        if (_periods.hasClients) {
          unawaited(_periods.animateToItem(pm ? 1 : 0, duration: _nudgeDuration, curve: Curves.easeOutCubic));
        }
      }
      _turn = turn;
      setState(() => _hour = index + (pm ? 12 : 0));
    }
    _emit();
  }

  void _minuteChanged(int index, int raw) {
    setState(() => _minute = index * widget.minuteInterval);
    _emit();
  }

  void _periodChanged(int index, int raw) {
    setState(() => _hour = _hour % 12 + (index == 1 ? 12 : 0));
    _emit();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _hourLabel(int index) => widget.use24hFormat ? _two(index) : '${index == 0 ? 12 : index}';

  @override
  Widget build(BuildContext context) {
    final minutes = 60 ~/ widget.minuteInterval;
    return _WheelGroup(
      height: widget.height,
      enabled: _enabled,
      semanticLabel: widget.semanticLabel,
      wheels: [
        (
          72,
          _Wheel(
            controller: _hours,
            itemCount: widget.use24hFormat ? 24 : 12,
            looping: true,
            enabled: _enabled,
            onSelected: _hourChanged,
            itemBuilder: (context, index) => Text(_hourLabel(index)),
            semanticLabel: 'Hour',
            semanticValue: _hourLabel,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
          ),
        ),
        (
          72,
          _Wheel(
            controller: _minutes,
            itemCount: minutes,
            looping: true,
            enabled: _enabled,
            onSelected: _minuteChanged,
            itemBuilder: (context, index) => Text(_two(index * widget.minuteInterval)),
            semanticLabel: 'Minute',
            semanticValue: (index) => _two(index * widget.minuteInterval),
          ),
        ),
        if (!widget.use24hFormat)
          (
            72,
            _Wheel(
              controller: _periods,
              itemCount: 2,
              enabled: _enabled,
              onSelected: _periodChanged,
              itemBuilder: (context, index) => Text(index == 0 ? 'AM' : 'PM'),
              semanticLabel: 'AM or PM',
              semanticValue: (index) => index == 0 ? 'AM' : 'PM',
            ),
          ),
      ],
    );
  }
}

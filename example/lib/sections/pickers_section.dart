import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

/// Picking values: a range slider, wheel pickers, a star rating and a
/// one-time-code field, each with its live value.
class PickersSection extends StatefulWidget {
  const PickersSection({super.key});

  @override
  State<PickersSection> createState() => _PickersSectionState();
}

class _PickersSectionState extends State<PickersSection> {
  static const List<String> _fruits = ['Apple', 'Banana', 'Cherry', 'Grape', 'Lemon', 'Mango', 'Orange', 'Peach'];

  GlassRange _price = const GlassRange(20, 80);
  int _fruit = 2;
  DateTime _date = DateTime(2026, 6, 15);
  DateTime _time = DateTime(2026, 1, 1, 9, 41);
  bool _use24h = false;
  double _rating = 3.5;
  String _code = '';
  bool _codeError = false;
  String? _codeStatus;

  String _two(int n) => n.toString().padLeft(2, '0');

  String get _timeLabel {
    if (_use24h) return '${_two(_time.hour)}:${_two(_time.minute)}';
    final hour = _time.hour % 12 == 0 ? 12 : _time.hour % 12;
    return '$hour:${_two(_time.minute)} ${_time.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _codeCompleted(String code) {
    // The demo's code is 123456; anything else shakes.
    setState(() {
      _codeError = code != '123456';
      _codeStatus = _codeError ? 'Wrong code, try 123456' : 'Verified';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final label = TextStyle(color: theme.foreground, fontSize: 14);
    final muted = TextStyle(color: theme.muted, fontSize: 13);
    Widget caption(String title, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(title, style: label)),
            Text(value, style: muted),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption('Price', '\$${_price.start.round()} – \$${_price.end.round()}'),
        GlassRangeSlider(
          values: _price,
          min: 0,
          max: 100,
          divisions: 20,
          semanticLabel: 'Price',
          semanticFormatter: (v) => '\$${v.round()}',
          onChanged: (v) => setState(() => _price = v),
        ),
        const SizedBox(height: 20),
        caption('Fruit', _fruits[_fruit]),
        GlassPicker(
          items: _fruits,
          initialItem: _fruit,
          looping: true,
          height: 180,
          semanticLabel: 'Fruit',
          onSelectedItemChanged: (i) => setState(() => _fruit = i),
        ),
        const SizedBox(height: 20),
        caption('Date', '${glassMonthNames[_date.month - 1]} ${_date.day}, ${_date.year}'),
        Center(
          child: GlassDatePicker(
            initialDate: _date,
            minimumYear: 1950,
            maximumYear: 2050,
            height: 180,
            semanticLabel: 'Date',
            onDateTimeChanged: (d) => setState(() => _date = d),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: caption('Time', _timeLabel)),
          const SizedBox(width: 12),
          Text('24-hour', style: muted),
          const SizedBox(width: 8),
          GlassSwitch(value: _use24h, onChanged: (v) => setState(() => _use24h = v)),
        ]),
        Center(
          child: GlassTimePicker(
            // A new key rebuilds the wheels when the format changes.
            key: ValueKey(_use24h),
            initialTime: _time,
            use24hFormat: _use24h,
            height: 180,
            semanticLabel: 'Time',
            onDateTimeChanged: (t) => setState(() => _time = t),
          ),
        ),
        const SizedBox(height: 20),
        caption('Rating', '$_rating of 5'),
        Row(children: [
          GlassRating(
            value: _rating,
            allowHalf: true,
            semanticLabel: 'Rating',
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(width: 16),
          Text('Average', style: muted),
          const SizedBox(width: 8),
          const GlassRating(value: 4.3, onChanged: null, size: 16, spacing: 2),
        ]),
        const SizedBox(height: 20),
        caption('Verification code', _codeStatus ?? (_code.isEmpty ? 'Type 123456' : _code)),
        Center(
          child: GlassPinField(
            error: _codeError,
            semanticLabel: 'Verification code',
            onChanged: (v) => setState(() {
              _code = v;
              _codeError = false;
              _codeStatus = null;
            }),
            onCompleted: _codeCompleted,
          ),
        ),
      ],
    );
  }
}

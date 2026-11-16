import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

/// The extras: slide to confirm, avatars, colour swatches, knobs and a calendar.
class ExtrasSection extends StatefulWidget {
  const ExtrasSection({super.key});

  @override
  State<ExtrasSection> createState() => _ExtrasSectionState();
}

class _ExtrasSectionState extends State<ExtrasSection> {
  static const List<Color> _colors = [
    Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00),
    Color(0xFF34C759), //
    Color(0xFF00C7BE), Color(0xFF007AFF), Color(0xFFAF52DE), Color(0xFFFF2D55),
  ];
  static const List<String> _colorNames = ['Red', 'Orange', 'Yellow', 'Green', 'Teal', 'Blue', 'Purple', 'Pink'];

  int _confirmed = 0;
  Color _accent = _colors[5];
  double _volume = 0.6;
  double _temperature = 21;
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final label = TextStyle(color: theme.foreground, fontSize: 14);
    final muted = TextStyle(color: theme.muted, fontSize: 13);
    final date = _date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSlideToConfirm(
          label: 'Slide to pay',
          confirmedLabel: 'Paid',
          activeColor: _accent,
          resetAfter: const Duration(seconds: 2),
          onConfirmed: () => setState(() => _confirmed++),
        ),
        const SizedBox(height: 6),
        Text(_confirmed == 0 ? 'Not paid yet' : 'Paid $_confirmed time${_confirmed == 1 ? '' : 's'}', style: muted),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const GlassAvatar(initials: 'Ada Lovelace', status: GlassAvatarStatus.online, size: 48),
            const GlassAvatar(initials: 'Alan Turing', status: GlassAvatarStatus.away, size: 48),
            const GlassAvatar(icon: Icon(Icons.pets), status: GlassAvatarStatus.busy, size: 48),
            const GlassAvatar(size: 48, semanticLabel: 'Guest'),
            GlassAvatarGroup(
              max: 3,
              size: 36,
              semanticLabel: 'Seven people',
              children: [
                for (final name in const [
                  'Grace Hopper',
                  'Linus T',
                  'Margaret H',
                  'Ken T',
                  'Barbara L',
                  'Don K',
                  'Edsger D'
                ])
                  GlassAvatar(initials: name, size: 36),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Accent', style: label),
        const SizedBox(height: 6),
        GlassColorSwatches(
          colors: _colors,
          labels: _colorNames,
          value: _accent,
          semanticLabel: 'Accent colour',
          onChanged: (color) => setState(() => _accent = color),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(children: [
              GlassKnob(
                value: _volume,
                activeColor: _accent,
                semanticLabel: 'Volume',
                onChanged: (v) => setState(() => _volume = v),
                child: Text('${(_volume * 100).round()}'),
              ),
              const SizedBox(height: 6),
              Text('Volume', style: muted),
            ]),
            Column(children: [
              GlassKnob(
                value: _temperature,
                min: 16,
                max: 28,
                divisions: 24,
                size: 72,
                activeColor: _accent,
                semanticLabel: 'Temperature',
                semanticFormatter: (v) => '${v.toStringAsFixed(1)} degrees',
                onChanged: (v) => setState(() => _temperature = v),
                child: Text('${_temperature.toStringAsFixed(1)}°'),
              ),
              const SizedBox(height: 6),
              Text('Temperature', style: muted),
            ]),
            Column(children: [
              const GlassKnob(value: 0.3, onChanged: null, semanticLabel: 'Locked'),
              const SizedBox(height: 6),
              Text('Disabled', style: muted),
            ]),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: GlassCalendar(
            selectedDate: _date,
            activeColor: _accent,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            onDateSelected: (day) => setState(() => _date = day),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          date == null ? 'No date picked' : 'Picked ${date.day}/${date.month}/${date.year}',
          style: muted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

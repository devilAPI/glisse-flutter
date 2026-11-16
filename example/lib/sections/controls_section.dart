import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

/// The small controls: checkboxes, radios, a stepper, chips, progress, page
/// dots, badges and a button group.
class ControlsSection extends StatefulWidget {
  const ControlsSection({super.key});

  @override
  State<ControlsSection> createState() => _ControlsSectionState();
}

class _ControlsSectionState extends State<ControlsSection> {
  bool _notify = true;
  bool? _all = false;
  String _size = 'm';
  double _guests = 2;
  final Set<String> _filters = {'All'};
  final List<String> _tags = ['Travel', 'Food', 'Friends'];
  double _progress = 0.35;
  bool _loading = true;
  double _page = 1;
  int _unread = 3;
  bool _bold = true;
  bool _italic = false;

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Progress that keeps moving, to show the spring.
    _tick = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _progress = _progress >= 1 ? 0.1 : (_progress + 0.15).clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final label = TextStyle(color: theme.foreground, fontSize: 14);
    Widget row(Widget leading, String text, [Widget? trailing]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: label)),
          if (trailing != null) trailing,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(GlassCheckbox(value: _notify, onChanged: (v) => setState(() => _notify = v!)), 'Notify me'),
        row(
          GlassCheckbox(value: _all, tristate: true, onChanged: (v) => setState(() => _all = v)),
          'Select all (tristate)',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (value, name) in const [('s', 'Small'), ('m', 'Medium'), ('l', 'Large')]) ...[
              GlassRadio<String>(value: value, groupValue: _size, onChanged: (v) => setState(() => _size = v)),
              const SizedBox(width: 8),
              Text(name, style: label),
              const SizedBox(width: 18),
            ],
          ],
        ),
        const SizedBox(height: 8),
        row(
          const Icon(Icons.group_outlined),
          'Guests: ${_guests.toInt()}',
          GlassStepper(value: _guests, min: 1, max: 12, onChanged: (v) => setState(() => _guests = v)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in const ['All', 'Photos', 'Videos', 'Live'])
              GlassChip(
                label: Text(filter),
                selected: _filters.contains(filter),
                onSelected: (on) => setState(() => on ? _filters.add(filter) : _filters.remove(filter)),
              ),
            for (final tag in _tags)
              GlassChip(
                label: Text(tag),
                icon: const Icon(Icons.tag),
                onSelected: (_) {},
                onDeleted: () => setState(() => _tags.remove(tag)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: GlassProgressBar(value: _progress)),
            const SizedBox(width: 16),
            GlassProgressRing(value: _progress, child: Text('${(_progress * 100).round()}')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: GlassProgressBar(value: _loading ? null : 1)),
            const SizedBox(width: 16),
            GlassActivityIndicator(animating: _loading),
            const SizedBox(width: 8),
            GlassButton(
              icon: Icon(_loading ? Icons.stop : Icons.play_arrow),
              semanticLabel: _loading ? 'Stop' : 'Start',
              onPressed: () => setState(() => _loading = !_loading),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlassPageIndicator(count: 5, page: _page, onTap: (i) => setState(() => _page = i.toDouble())),
            GestureDetector(
              onTap: () => setState(() => _unread = _unread >= 9 ? 0 : _unread + 1),
              child: GlassBadge(
                label: '$_unread',
                show: _unread > 0,
                child: Icon(Icons.mail_outline, size: 28, color: theme.foreground),
              ),
            ),
            GlassButtonGroup(
              children: [
                GlassButtonGroupItem(
                  icon: const Icon(Icons.format_bold),
                  semanticLabel: 'Bold',
                  selected: _bold,
                  onPressed: () => setState(() => _bold = !_bold),
                ),
                GlassButtonGroupItem(
                  icon: const Icon(Icons.format_italic),
                  semanticLabel: 'Italic',
                  selected: _italic,
                  onPressed: () => setState(() => _italic = !_italic),
                ),
                GlassButtonGroupItem(icon: const Icon(Icons.undo), semanticLabel: 'Undo', onPressed: () {}),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

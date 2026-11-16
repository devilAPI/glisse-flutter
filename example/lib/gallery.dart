import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

import 'sections/controls_section.dart';
import 'sections/magnifier_section.dart';
import 'sections/navigation_section.dart';
import 'sections/overlays_section.dart';
import 'wallpaper.dart';

/// Every Glisse widget, over a wallpaper the glass bends.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.dark, required this.onToggleTheme, this.animateWallpaper = true});

  final bool dark;
  final VoidCallback onToggleTheme;
  final bool animateWallpaper;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final ScrollController _scroll = ScrollController(
    initialScrollOffset: double.tryParse(const String.fromEnvironment('SCROLL')) ?? 0,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Playground tuning, as on glisse.kelvinzhang.ca.
  double _bend = 2;
  double _dispersion = 0.6;
  double _blur = 3;
  double _rim = 0.3;
  GlassMode _mode = GlassMode.auto;
  late bool _animate = widget.animateWallpaper;

  bool _wifi = true;
  bool _bluetooth = false;
  bool _airplane = false;
  double _volume = 0.6;
  double _brightness = 0.35;
  String _view = 'day';
  String _tab = 'home';
  String _iconTab = 'listen';
  String _lastAction = 'Nothing yet';
  Offset _lens = const Offset(40, 40);

  @override
  Widget build(BuildContext context) {
    final base = widget.dark ? GlassThemeData.dark() : GlassThemeData.light();
    final theme = base.copyWith(
      glassBend: _bend,
      glassDispersion: _dispersion,
      blur: _blur,
      rimShine: widget.dark ? _rim * 0.43 : _rim,
      mode: _mode,
    );
    return GlassTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GlassBackdrop(
          background: Wallpaper(dark: widget.dark, animate: _animate),
          child: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 72, 16, 140),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _content(theme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _topBar(theme))),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: GlassTabBar<String>(
                      items: const [
                        GlassSegment(value: 'home', label: 'Home'),
                        GlassSegment(value: 'browse', label: 'Browse'),
                        GlassSegment(value: 'radio', label: 'Radio'),
                        GlassSegment(value: 'library', label: 'Library'),
                      ],
                      value: _tab,
                      onChanged: (v) => setState(() => _tab = v),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(GlassThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Glass(
            borderRadius: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('Glisse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.foreground)),
          ),
          const Spacer(),
          GlassButton(
            icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            semanticLabel: 'Toggle theme',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
          GlassMenu(
            semanticLabel: 'More',
            items: [
              GlassMenuItem(
                label: Text(_animate ? 'Pause wallpaper' : 'Animate wallpaper'),
                icon: Icon(_animate ? Icons.pause : Icons.play_arrow),
                onSelected: () => setState(() => _animate = !_animate),
              ),
              GlassMenuItem(
                label: const Text('Reset tuning'),
                icon: const Icon(Icons.restart_alt),
                onSelected: () => setState(() {
                  _bend = 2;
                  _dispersion = 0.6;
                  _blur = 3;
                  _rim = 0.3;
                }),
              ),
              const GlassMenuSeparator(),
              GlassMenuItem(
                label: const Text('Delete everything'),
                icon: const Icon(Icons.delete_outline),
                destructive: true,
                onSelected: () => setState(() => _lastAction = 'Deleted everything (not really)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _content(GlassThemeData theme) {
    final label = TextStyle(color: theme.foreground, fontSize: 14);
    final muted = TextStyle(color: theme.muted, fontSize: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(theme),
        const SizedBox(height: 28),
        _Section(
          title: 'Buttons',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GlassButton(onPressed: () => _did('Glass'), child: const Text('Glass')),
                GlassButton(
                  onPressed: () => _did('Continue'),
                  variant: GlassButtonVariant.filled,
                  child: const Text('Continue'),
                ),
                GlassButton(
                  onPressed: () => _did('Share'),
                  icon: const Icon(Icons.ios_share),
                  child: const Text('Share'),
                ),
                GlassButton(
                  onPressed: () => _did('Delete'),
                  destructive: true,
                  icon: const Icon(Icons.delete_outline),
                  child: const Text('Delete'),
                ),
                GlassButton(onPressed: () => _did('Add'), icon: const Icon(Icons.add), semanticLabel: 'Add'),
                GlassButton(
                  onPressed: () => _did('Favourite'),
                  icon: const Icon(Icons.favorite),
                  tint: Colors.pinkAccent,
                  semanticLabel: 'Favourite',
                ),
                const GlassButton(onPressed: null, child: Text('Disabled')),
              ],
            ),
            const SizedBox(height: 10),
            Text('Last action: $_lastAction', style: muted),
          ],
        ),
        _Section(
          title: 'Switch',
          children: [
            _row('Wi-Fi', GlassSwitch(value: _wifi, onChanged: (v) => setState(() => _wifi = v)), label),
            _row('Bluetooth', GlassSwitch(value: _bluetooth, onChanged: (v) => setState(() => _bluetooth = v)), label),
            _row(
              'Airplane mode',
              GlassSwitch(
                value: _airplane,
                activeColor: Colors.orange,
                onChanged: (v) => setState(() => _airplane = v),
              ),
              label,
            ),
            _row('Disabled', const GlassSwitch(value: true, onChanged: null), label),
          ],
        ),
        _Section(
          title: 'Slider',
          children: [
            Row(children: [
              Icon(Icons.volume_down, color: theme.muted),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GlassSlider(value: _volume, onChanged: (v) => setState(() => _volume = v)),
                ),
              ),
              Icon(Icons.volume_up, color: theme.muted),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.brightness_low, color: theme.muted),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GlassSlider(
                    value: _brightness,
                    divisions: 10,
                    activeColor: Colors.amber,
                    onChanged: (v) => setState(() => _brightness = v),
                  ),
                ),
              ),
              Icon(Icons.brightness_high, color: theme.muted),
            ]),
          ],
        ),
        _Section(
          title: 'Segmented control',
          children: [
            Center(
              child: GlassSegmentedControl<String>(
                segments: const [
                  GlassSegment(value: 'day', label: 'Day'),
                  GlassSegment(value: 'week', label: 'Week'),
                  GlassSegment(value: 'month', label: 'Month'),
                  GlassSegment(value: 'year', label: 'Year'),
                ],
                value: _view,
                onChanged: (v) => setState(() => _view = v),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Tab bar',
          children: [
            Center(
              child: GlassTabBar<String>(
                items: const [
                  GlassSegment(value: 'listen', label: 'Listen Now', icon: Icons.play_circle_fill),
                  GlassSegment(value: 'browse', label: 'Browse', icon: Icons.grid_view_rounded),
                  GlassSegment(value: 'radio', label: 'Radio', icon: Icons.sensors),
                  GlassSegment(value: 'search', label: 'Search', icon: Icons.search),
                ],
                value: _iconTab,
                onChanged: (v) => setState(() => _iconTab = v),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Input',
          children: [
            const GlassSearchField(),
            const SizedBox(height: 10),
            const GlassInput(placeholder: 'Email address', icon: Icon(Icons.mail_outline)),
            const SizedBox(height: 10),
            const GlassInput(placeholder: 'Password', icon: Icon(Icons.lock_outline), obscureText: true),
          ],
        ),
        const _Section(title: 'Controls', children: [ControlsSection()]),
        const _Section(title: 'Overlays', children: [OverlaysSection()]),
        const _Section(title: 'Navigation', children: [NavigationSection()]),
        const _Section(title: 'Magnifier', children: [MagnifierSection()]),
        _Section(
          title: 'Playground',
          children: [
            Center(
              child: GlassSegmentedControl<GlassMode>(
                segments: const [
                  GlassSegment(value: GlassMode.auto, label: 'Auto'),
                  GlassSegment(value: GlassMode.captured, label: 'Captured'),
                  GlassSegment(value: GlassMode.backdropFilter, label: 'Live'),
                  GlassSegment(value: GlassMode.frost, label: 'Frost'),
                ],
                value: _mode,
                onChanged: (v) => setState(() => _mode = v),
              ),
            ),
            const SizedBox(height: 12),
            _tuner('Bend', _bend, 0, 4, (v) => setState(() => _bend = v), label),
            _tuner('Dispersion', _dispersion, 0, 3, (v) => setState(() => _dispersion = v), label),
            _tuner('Frost', _blur, 0, 12, (v) => setState(() => _blur = v), label),
            _tuner('Rim light', _rim, 0, 1, (v) => setState(() => _rim = v), label),
          ],
        ),
      ],
    );
  }

  Widget _hero(GlassThemeData theme) {
    return SizedBox(
      height: 260,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final max = Offset(constraints.maxWidth - 200, constraints.maxHeight - 120);
          final at = Offset(_lens.dx.clamp(0, max.dx), _lens.dy.clamp(0, max.dy));
          return Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Text(
                    'Liquid Glass,\nfor Flutter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: theme.foreground,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: at.dx,
                top: at.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() => _lens = at + d.delta),
                  child: const Glass(
                    width: 200,
                    height: 120,
                    borderRadius: 60,
                    child: Center(child: Text('Drag me')),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String title, Widget control, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [Expanded(child: Text(title, style: style)), control]),
    );
  }

  Widget _tuner(String title, double value, double min, double max, ValueChanged<double> onChanged, TextStyle style) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(title, style: style)),
        Expanded(child: GlassSlider(value: value, min: min, max: max, onChanged: onChanged)),
        SizedBox(width: 44, child: Text(value.toStringAsFixed(2), textAlign: TextAlign.right, style: style)),
      ],
    );
  }

  void _did(String what) => setState(() => _lastAction = what);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Glass(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(color: theme.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

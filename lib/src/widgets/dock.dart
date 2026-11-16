import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';
import 'glass.dart';

/// One app in a [GlassDock].
@immutable
class GlassDockItem {
  const GlassDockItem({required this.icon, required this.label, this.onPressed, this.running = false});

  /// Drawn to fill the item's square, such as an app icon.
  final Widget icon;

  /// Shown over the item while it's hovered.
  final String label;
  final VoidCallback? onPressed;

  /// Marks the item with a dot underneath, as a running app.
  final bool running;
}

/// A dock of glass, as macOS's: its icons swell as the pointer nears them,
/// each by how close it is, show their name while hovered, and bounce when
/// opened. A finger dragged along it swells them too.
class GlassDock extends StatefulWidget {
  const GlassDock({
    super.key,
    required this.items,
    this.iconSize = 48,
    this.magnification = 1.6,
    this.spacing = 8,
  });

  final List<GlassDockItem> items;

  /// Each icon's size at rest.
  final double iconSize;

  /// How much the icon under the pointer swells.
  final double magnification;
  final double spacing;

  @override
  State<GlassDock> createState() => _GlassDockState();
}

class _GlassDockState extends State<GlassDock> with TickerProviderStateMixin {
  final List<GlassSpring> _scales = [];
  final List<GlassSpring> _bounces = [];
  int _hovered = -1;
  late Listenable _motion;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GlassDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final s in [..._scales, ..._bounces]) {
      s.reduceMotion = reduce;
    }
  }

  void _sync() {
    while (_scales.length < widget.items.length) {
      _scales.add(GlassSpring(vsync: this, value: 1, stiffness: 900, damping: 52));
      _bounces.add(GlassSpring(vsync: this, stiffness: 260, damping: 11));
    }
    while (_scales.length > widget.items.length) {
      _scales.removeLast().dispose();
      _bounces.removeLast().dispose();
    }
    if (_hovered >= widget.items.length) _hovered = -1;
    _motion = Listenable.merge([..._scales, ..._bounces]);
  }

  @override
  void dispose() {
    for (final s in [..._scales, ..._bounces]) {
      s.dispose();
    }
    super.dispose();
  }

  double get _pad => 8;

  // Swells each icon by its distance from the pointer, measured at rest so
  // the icons don't run from it as they grow.
  void _point(double x) {
    final step = widget.iconSize + widget.spacing;
    final reach = widget.iconSize * 2.2;
    var nearest = -1;
    var best = double.infinity;
    for (var i = 0; i < _scales.length; i++) {
      final centre = _pad + i * step + widget.iconSize / 2;
      final d = (x - centre).abs();
      if (d < best) {
        best = d;
        nearest = i;
      }
      final t = math.exp(-math.pow(d / reach, 2) * 2.2);
      _scales[i].set(1 + (widget.magnification - 1) * t);
    }
    final hovered = best <= step / 2 ? nearest : -1;
    if (hovered != _hovered) setState(() => _hovered = hovered);
  }

  void _leave() {
    for (final s in _scales) {
      s.set(1);
    }
    if (_hovered != -1) setState(() => _hovered = -1);
  }

  void _open(int i) {
    // A hop up, falling back with a bounce.
    _bounces[i].jump(0, velocity: -520);
    widget.items[i].onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final size = widget.iconSize;
    final tallest = size * widget.magnification;
    final bar = size + _pad * 2;

    return MouseRegion(
      onHover: (e) => _point(e.localPosition.dx),
      onExit: (_) => _leave(),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => _point(d.localPosition.dx),
        onHorizontalDragEnd: (_) => _leave(),
        onHorizontalDragCancel: _leave,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final icons = <Widget>[];
            for (var i = 0; i < widget.items.length; i++) {
              final item = widget.items[i];
              final s = size * _scales[i].value;
              if (i > 0) icons.add(SizedBox(width: widget.spacing));
              icons.add(
                Semantics(
                  button: true,
                  label: item.label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _open(i),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: SizedBox(
                        width: s,
                        height: tallest + 22,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned(
                              // The bounce rises above rest and lands on it, as on a floor.
                              bottom: _pad - math.min(0.0, _bounces[i].value),
                              child: SizedBox.square(dimension: s, child: FittedBox(child: item.icon)),
                            ),
                            if (item.running)
                              Positioned(
                                bottom: 2,
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(color: theme.foreground, shape: BoxShape.circle),
                                ),
                              ),
                            if (_hovered == i)
                              Positioned(
                                bottom: _pad + s + 8,
                                child: IgnorePointer(
                                  child: Glass(
                                    borderRadius: 10,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: base.copyWith(color: theme.foreground, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bar,
                  child: const Glass(borderRadius: 22),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: _pad),
                  child:
                      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: icons),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

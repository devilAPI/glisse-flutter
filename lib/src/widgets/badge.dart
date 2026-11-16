import 'package:flutter/widgets.dart';

import '../foundation/spring.dart';
import '../foundation/theme.dart';

/// A red badge at the top right of [child], as on an app icon or a tab. It
/// pops in on a bouncy spring when [show] turns on, and shrinks away when off.
/// Without a [label] it's a dot.
class GlassBadge extends StatefulWidget {
  const GlassBadge({
    super.key,
    required this.child,
    this.label,
    this.show = true,
    this.color,
    this.offset = const Offset(6, -6),
  });

  final Widget child;
  final String? label;
  final bool show;

  /// Defaults to the theme's destructive red.
  final Color? color;

  /// How far the badge's centre-right sits past the child's top-right corner.
  final Offset offset;

  @override
  State<GlassBadge> createState() => _GlassBadgeState();
}

class _GlassBadgeState extends State<GlassBadge> with SingleTickerProviderStateMixin {
  late final GlassSpring _pop = GlassSpring(vsync: this, value: widget.show ? 1 : 0, stiffness: 500, damping: 17);
  String? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.label;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pop.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(GlassBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show) _shown = widget.label;
    if (widget.show != oldWidget.show) {
      if (widget.show) _pop.set(0, instant: true);
      _pop.set(widget.show ? 1 : 0);
    } else if (widget.show && widget.label != oldWidget.label && oldWidget.label != null) {
      // A new count bumps the badge.
      _pop.jump(1.0, velocity: 6);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final color = widget.color ?? theme.destructive;
    final label = _shown;
    final badge = Container(
      constraints: BoxConstraints(minWidth: label == null ? 10 : 18, minHeight: label == null ? 10 : 18),
      padding: label == null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: label == null
          ? null
          : Text(
              label,
              maxLines: 1,
              style: theme.textStyle.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
    );
    return Semantics(
      value: widget.show ? (label ?? 'New') : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            top: widget.offset.dy,
            right: -widget.offset.dx,
            child: AnimatedBuilder(
              animation: _pop,
              builder: (context, child) {
                final s = _pop.value;
                if (s <= 0.001) return const SizedBox.shrink();
                return Opacity(
                  opacity: s.clamp(0.0, 1.0),
                  child: Transform.scale(scale: s.clamp(0.0, 1.6), child: child),
                );
              },
              child: ExcludeSemantics(child: badge),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

/// An original, colourful backdrop for the gallery: soft glowing blobs over
/// a gradient, fine lines and large letters, so the glass has something to bend.
class Wallpaper extends StatefulWidget {
  const Wallpaper({super.key, required this.dark, this.animate = true});

  final bool dark;
  final bool animate;

  @override
  State<Wallpaper> createState() => _WallpaperState();
}

class _WallpaperState extends State<Wallpaper> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _drift.repeat();
  }

  @override
  void didUpdateWidget(Wallpaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_drift.isAnimating) _drift.repeat();
    if (!widget.animate && _drift.isAnimating) _drift.stop();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Without WebGL, Flutter draws every pixel on the CPU, where one
    // full-screen gradient takes 400 ms a frame: the wallpaper goes flat.
    final painter = GlassShaders.usable ? _WallpaperPainter(widget.dark, _drift) : _FlatWallpaperPainter(widget.dark);
    return RepaintBoundary(child: CustomPaint(painter: painter, size: Size.infinite));
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.dark, this.drift) : super(repaint: drift);

  final bool dark;
  final Animation<double> drift;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              dark
                  ? const [Color(0xFF0B1026), Color(0xFF2A1450), Color(0xFF071E2E)]
                  : const [Color(0xFFFFE3C7), Color(0xFFE2D9FF), Color(0xFFC8F1FF)],
        ).createShader(rect),
    );

    final t = drift.value * 2 * math.pi;
    final blobs = <(Offset, double, Color)>[
      (Offset(0.18 + 0.05 * math.sin(t), 0.22 + 0.04 * math.cos(t)), 0.34, const Color(0xFFFF5E62)),
      (Offset(0.82 + 0.04 * math.cos(t * 2), 0.18 + 0.05 * math.sin(t)), 0.30, const Color(0xFF00C6FF)),
      (Offset(0.65 + 0.06 * math.sin(t + 1), 0.62 + 0.05 * math.cos(t * 2)), 0.36, const Color(0xFF8E2DE2)),
      (Offset(0.22 + 0.05 * math.cos(t + 2), 0.78 + 0.04 * math.sin(t)), 0.30, const Color(0xFFFFC837)),
      (Offset(0.50 + 0.03 * math.sin(t * 3), 0.40 + 0.03 * math.cos(t)), 0.20, const Color(0xFF11998E)),
    ];
    final scale = math.max(size.width, size.height);
    // Soft blobs, as radial gradients rather than blurred discs: a blur that
    // wide is costly every time the wallpaper is drawn (on the web, every
    // frame), and costs the CPU seconds where a browser has no WebGL.
    for (final (at, radius, color) in blobs) {
      final centre = Offset(at.dx * size.width, at.dy * size.height);
      final solid = radius * scale * 0.6;
      final sigma = scale * 0.08;
      final reach = solid + 2 * sigma;
      final tone = color.withValues(alpha: dark ? 0.55 : 0.65);
      canvas.drawCircle(
        centre,
        reach,
        Paint()
          ..shader = RadialGradient(
            colors: [tone, tone, tone.withValues(alpha: tone.a * 0.5), tone.withValues(alpha: 0)],
            stops: [0, ((solid - sigma) / reach).clamp(0.0, 1.0), solid / reach, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: reach)),
      );
    }

    // Fine lines, which show the bend at the glass's rim best.
    final line =
        Paint()
          ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.10)
          ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final words = TextPainter(
      text: TextSpan(
        text: 'glisse  glisse  glisse  glisse  glisse  glisse',
        style: TextStyle(
          fontSize: 120,
          fontWeight: FontWeight.w800,
          letterSpacing: -4,
          color: (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.12 : 0.08),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    for (var y = -40.0; y < size.height; y += 220) {
      words.paint(canvas, Offset(-60 - (y % 3) * 40, y));
    }
  }

  @override
  bool shouldRepaint(_WallpaperPainter oldDelegate) => oldDelegate.dark != dark;
}

/// The wallpaper in flat colours, cheap to draw on the CPU: solid blobs and
/// the fine lines, without gradients or large letters.
class _FlatWallpaperPainter extends CustomPainter {
  _FlatWallpaperPainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? const Color(0xFF1A1438) : const Color(0xFFEDE6FF));
    final scale = math.max(size.width, size.height);
    for (final (at, radius, color) in const [
      (Offset(0.18, 0.22), 0.2, Color(0xFFFF5E62)),
      (Offset(0.82, 0.18), 0.18, Color(0xFF00C6FF)),
      (Offset(0.65, 0.62), 0.22, Color(0xFF8E2DE2)),
      (Offset(0.22, 0.78), 0.18, Color(0xFFFFC837)),
    ]) {
      canvas.drawCircle(
        Offset(at.dx * size.width, at.dy * size.height),
        radius * scale,
        Paint()..color = color.withValues(alpha: dark ? 0.35 : 0.4),
      );
    }
    final line =
        Paint()
          ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.10)
          ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_FlatWallpaperPainter oldDelegate) => oldDelegate.dark != dark;
}

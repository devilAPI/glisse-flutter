import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

/// A magnifying glass to drag over the page, and a loupe that rises under a
/// long press.
class MagnifierSection extends StatelessWidget {
  const MagnifierSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Drag the lens over the page.', style: TextStyle(color: theme.muted, fontSize: 13)),
        const SizedBox(height: 8),
        const SizedBox(height: 220, child: GlassMagnifier(size: 140, magnification: 1.8)),
        const SizedBox(height: 12),
        GlassLoupeRegion(
          child: Container(
            height: 90,
            alignment: Alignment.center,
            child: Text('Press and hold here for a loupe.', style: TextStyle(color: theme.foreground, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

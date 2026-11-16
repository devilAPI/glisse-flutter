import 'package:flutter/material.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

/// A magnifying glass and a loupe: in this section, or floating over the
/// whole page.
class MagnifierSection extends StatelessWidget {
  const MagnifierSection({super.key, required this.pageLens});

  /// Whether the lenses float over the whole page instead.
  final ValueNotifier<bool> pageLens;

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final muted = TextStyle(color: theme.muted, fontSize: 13);
    return ValueListenableBuilder<bool>(
      valueListenable: pageLens,
      builder:
          (context, floating, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Lenses over the whole page', style: TextStyle(color: theme.foreground, fontSize: 14)),
                  ),
                  GlassSwitch(
                    value: floating,
                    semanticLabel: 'Lenses over the whole page',
                    onChanged: (v) => pageLens.value = v,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (floating)
                Text(
                  'Drag the lens anywhere: it magnifies everything, glass included. Press and hold anywhere for the '
                  'loupe.',
                  style: muted,
                )
              else ...[
                Text('Drag the lens around this box.', style: muted),
                const SizedBox(height: 8),
                const SizedBox(height: 220, child: GlassMagnifier(size: 140, magnification: 1.8)),
                const SizedBox(height: 12),
                GlassLoupeRegion(
                  child: Container(
                    height: 90,
                    alignment: Alignment.center,
                    child: Text(
                      'Press and hold here for a loupe, then drag it anywhere.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.foreground, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:glisse_flutter/glisse_flutter.dart';

/// Buttons that open each of Glisse's overlays: an alert, a sheet, a toast,
/// a popover and a tooltip.
class OverlaysSection extends StatelessWidget {
  const OverlaysSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        GlassButton(
          icon: const Icon(Icons.warning_amber_rounded),
          onPressed:
              () => showGlassDialog<void>(
                context: context,
                builder:
                    (context) => GlassAlertDialog(
                      title: const Text('Delete this photo?'),
                      content: const Text('It will be removed from all your devices. This can’t be undone.'),
                      actions: [
                        const GlassDialogAction(child: Text('Cancel')),
                        GlassDialogAction(
                          destructive: true,
                          onPressed:
                              () => showGlassToast(
                                context,
                                icon: Icon(Icons.delete_outline, color: theme.destructive),
                                message: const Text('Photo deleted'),
                              ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              ),
          child: const Text('Alert'),
        ),
        GlassButton(
          icon: const Icon(Icons.vertical_align_top),
          onPressed:
              () => showGlassSheet<void>(
                context: context,
                builder:
                    (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Share', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          'Drag the sheet down, or tap outside it, to close it.',
                          style: TextStyle(color: theme.muted),
                        ),
                        const SizedBox(height: 16),
                        GlassButton(
                          variant: GlassButtonVariant.filled,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Send'),
                        ),
                        const SizedBox(height: 8),
                        GlassButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Save for later')),
                      ],
                    ),
              ),
          child: const Text('Sheet'),
        ),
        GlassButton(
          icon: const Icon(Icons.notifications_none),
          onPressed:
              () => showGlassToast(
                context,
                icon: const Icon(Icons.check_circle, color: Colors.green),
                message: const Text('Copied to clipboard'),
              ),
          child: const Text('Toast'),
        ),
        GlassPopover(
          width: 240,
          popoverBuilder:
              (context) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Popover', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'A card of glass that springs out of its anchor. Tap outside to close it.',
                    style: TextStyle(color: theme.muted),
                  ),
                ],
              ),
          child: IgnorePointer(
            child: GlassButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {},
              child: const Text('Popover'),
            ),
          ),
        ),
        GlassTooltip(
          message: 'Long-press or hover for a tooltip',
          child: GlassButton(icon: const Icon(Icons.info_outline), semanticLabel: 'Tooltip', onPressed: () {}),
        ),
      ],
    );
  }
}

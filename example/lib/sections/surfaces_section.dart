import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

/// Glass surfaces: an action sheet, a context menu, a notification banner,
/// cards and disclosure sections.
class SurfacesSection extends StatefulWidget {
  const SurfacesSection({super.key});

  @override
  State<SurfacesSection> createState() => _SurfacesSectionState();
}

class _SurfacesSectionState extends State<SurfacesSection> {
  String _status = 'Try the buttons, or long-press the photo.';
  bool _wifiOpen = false;
  bool _favourite = false;

  void _say(String status) => setState(() => _status = status);

  Future<void> _actionSheet() async {
    final choice = await showGlassActionSheet<String>(
      context: context,
      title: const Text('Sunset at the pier'),
      message: const Text('This photo is also in 2 albums.'),
      actions: const [
        GlassActionSheetAction(result: 'share', child: Text('Share…')),
        GlassActionSheetAction(result: 'album', isDefault: true, child: Text('Add to Album')),
        GlassActionSheetAction(result: 'delete', destructive: true, child: Text('Delete Photo')),
      ],
      cancel: const GlassActionSheetAction(result: 'cancel', child: Text('Cancel')),
    );
    if (!mounted) return;
    _say(choice == null ? 'Action sheet dismissed' : 'Action sheet: $choice');
  }

  void _banner() {
    showGlassBanner(
      context: context,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: const Color(0xFF34C759), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
      ),
      title: const Text('Messages'),
      message: const Text('Ana: Are we still on for dinner at eight?'),
      trailing: const Text('now'),
      onTap: () => _say('Banner tapped'),
    );
  }

  Widget _photo() {
    return GlassContextMenu(
      semanticLabel: 'Photo actions',
      items: [
        GlassMenuItem(label: const Text('Copy'), icon: const Icon(Icons.copy), onSelected: () => _say('Copied')),
        GlassMenuItem(label: const Text('Share'), icon: const Icon(Icons.ios_share), onSelected: () => _say('Shared')),
        GlassMenuItem(
          label: Text(_favourite ? 'Unfavourite' : 'Favourite'),
          icon: Icon(_favourite ? Icons.favorite : Icons.favorite_border),
          onSelected:
              () => setState(() {
                _favourite = !_favourite;
                _status = _favourite ? 'Added to favourites' : 'Removed from favourites';
              }),
        ),
        const GlassMenuSeparator(),
        GlassMenuItem(
          label: const Text('Delete'),
          icon: const Icon(Icons.delete_outline),
          destructive: true,
          onSelected: () => _say('Deleted (not really)'),
        ),
      ],
      child: Semantics(
        label: 'Photo, long-press for actions',
        image: true,
        child: Container(
          width: 140,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF9F0A), Color(0xFFFF375F), Color(0xFF5E5CE6)],
            ),
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_favourite) const Icon(Icons.favorite, color: Colors.white, size: 16),
              if (_favourite) const SizedBox(width: 4),
              const Text('Sunset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GlassButton(icon: const Icon(Icons.more_horiz), onPressed: _actionSheet, child: const Text('Action sheet')),
            GlassButton(icon: const Icon(Icons.notifications_none), onPressed: _banner, child: const Text('Banner')),
            _photo(),
          ],
        ),
        const SizedBox(height: 8),
        Text(_status, style: TextStyle(color: theme.muted, fontSize: 13)),
        const SizedBox(height: 14),
        GlassCard(
          leading: const Icon(Icons.wifi),
          title: const Text('Wi-Fi'),
          subtitle: const Text('Home network'),
          trailing: Transform.flip(
            flipX: Directionality.of(context) == TextDirection.rtl,
            child: GlassGlyph.chevron(color: theme.muted, size: 14),
          ),
          onTap: () => _say('Card tapped'),
          child: const Text('Connected, secured, 5 GHz. Tap the card.'),
        ),
        const SizedBox(height: 12),
        const GlassCard(title: Text('Battery'), subtitle: Text('Last charged to 100%'), trailing: Text('82%')),
        const SizedBox(height: 12),
        GlassDisclosure(
          leading: const Icon(Icons.tune),
          title: const Text('Advanced'),
          subtitle: const Text('Keeps its own state'),
          child: const Text('Proxy, DNS, and a private address for this network.'),
          onExpansionChanged: (open) => _say(open ? 'Advanced opened' : 'Advanced closed'),
        ),
        const SizedBox(height: 12),
        GlassListSection(
          header: const Text('Network'),
          children: [
            const GlassListTile(title: Text('Name'), trailing: Text('Home')),
            GlassDisclosure(
              inset: false,
              title: const Text('Details'),
              expanded: _wifiOpen,
              onExpansionChanged: (open) => setState(() => _wifiOpen = open),
              childPadding: EdgeInsets.zero,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassListTile(title: Text('IP address'), trailing: Text('192.168.1.24')),
                  GlassListTile(title: Text('Router'), trailing: Text('192.168.1.1')),
                ],
              ),
            ),
            GlassListTile(title: const Text('Forget this network'), onTap: () => _say('Forgot (not really)')),
          ],
        ),
      ],
    );
  }
}

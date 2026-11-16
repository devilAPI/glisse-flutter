import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

/// The navigation and container widgets: a floating navigation bar, a
/// toolbar, an inset grouped list, a sidebar and a dock.
class NavigationSection extends StatefulWidget {
  const NavigationSection({super.key});

  @override
  State<NavigationSection> createState() => _NavigationSectionState();
}

class _NavigationSectionState extends State<NavigationSection> {
  int _folder = 0;
  bool _bold = true;
  bool _italic = false;
  bool _airdrop = true;
  String _opened = 'Nothing opened yet';

  static Widget _appIcon(List<Color> colors, IconData icon) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: SizedBox.square(dimension: 48, child: Icon(icon, color: Colors.white, size: 28)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassNavigationBar(
          padding: EdgeInsets.zero,
          leading: GlassBackButton(label: 'Settings', onPressed: () {}),
          title: const Text('General'),
          actions: [
            GlassToolbar(
              padding: 0,
              children: [
                GlassToolbarItem(icon: const Icon(Icons.search), semanticLabel: 'Search', onPressed: () {}),
                GlassToolbarItem(icon: const Icon(Icons.more_horiz), semanticLabel: 'More', onPressed: () {}),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassListSection(
          header: const Text('Sharing'),
          footer: const Text('Nearby devices can find this one.'),
          children: [
            GlassListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('Wi-Fi'),
              trailing: const Text('Home'),
              showChevron: true,
              onTap: () {},
            ),
            GlassListTile(
              leading: const Icon(Icons.share),
              title: const Text('AirDrop'),
              trailing: GlassSwitch(value: _airdrop, onChanged: (v) => setState(() => _airdrop = v)),
            ),
            const GlassListTile(title: Text('Name'), subtitle: Text('Glisse’s phone')),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: GlassToolbar(
            children: [
              GlassToolbarItem(
                icon: const Icon(Icons.format_bold),
                semanticLabel: 'Bold',
                selected: _bold,
                onPressed: () => setState(() => _bold = !_bold),
              ),
              GlassToolbarItem(
                icon: const Icon(Icons.format_italic),
                semanticLabel: 'Italic',
                selected: _italic,
                onPressed: () => setState(() => _italic = !_italic),
              ),
              const GlassToolbarSpacer(),
              GlassToolbarItem(icon: const Icon(Icons.undo), semanticLabel: 'Undo', onPressed: () {}),
              GlassToolbarItem(icon: const Icon(Icons.redo), semanticLabel: 'Redo', onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GlassSidebar(
            header: const Text('Mail'),
            items: const [
              GlassSidebarItem(icon: Icon(Icons.inbox), label: 'Inbox', trailing: Text('12')),
              GlassSidebarItem(icon: Icon(Icons.star_border), label: 'Favourites'),
              GlassSidebarItem(icon: Icon(Icons.send_outlined), label: 'Sent'),
              GlassSidebarItem(icon: Icon(Icons.delete_outline), label: 'Trash'),
            ],
            selected: _folder,
            onSelected: (i) => setState(() => _folder = i),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GlassDock(
            items: [
              GlassDockItem(
                icon: _appIcon([Colors.blue, Colors.cyan], Icons.public),
                label: 'Browser',
                running: true,
                onPressed: () => setState(() => _opened = 'Opened Browser'),
              ),
              GlassDockItem(
                icon: _appIcon([Colors.green, Colors.teal], Icons.message),
                label: 'Messages',
                onPressed: () => setState(() => _opened = 'Opened Messages'),
              ),
              GlassDockItem(
                icon: _appIcon([Colors.orange, Colors.red], Icons.photo),
                label: 'Photos',
                running: true,
                onPressed: () => setState(() => _opened = 'Opened Photos'),
              ),
              GlassDockItem(
                icon: _appIcon([Colors.purple, Colors.pink], Icons.music_note),
                label: 'Music',
                onPressed: () => setState(() => _opened = 'Opened Music'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(_opened, textAlign: TextAlign.center, style: TextStyle(color: theme.muted, fontSize: 13)),
      ],
    );
  }
}

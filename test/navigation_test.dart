import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

Widget _appIcon(Color a, Color b, IconData icon) => DecoratedBox(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  child: SizedBox.square(dimension: 48, child: Icon(icon, color: Colors.white, size: 28)),
);

void main() {
  testWidgets('back button pops, actions tap', (tester) async {
    await setUpGlass(tester);
    var shared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Center(child: Text('Home'))),
        routes: {
          '/next':
              (_) => Scaffold(
                body: GlassNavigationBar(
                  leading: const GlassBackButton(label: 'Home'),
                  title: const Text('Detail'),
                  actions: [
                    GlassButton(onPressed: () => shared++, icon: const Icon(Icons.ios_share), semanticLabel: 'Share'),
                  ],
                ),
              ),
        },
      ),
    );
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/next'));
    await settle(tester);
    expect(find.text('Detail'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Share'));
    await settle(tester);
    expect(shared, 1);
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('toolbar items fire and disable', (tester) async {
    await setUpGlass(tester);
    var taps = 0;
    await tester.pumpWidget(
      scene(
        GlassToolbar(
          children: [
            GlassToolbarItem(icon: const Icon(Icons.edit), semanticLabel: 'Edit', onPressed: () => taps++),
            const GlassToolbarItem(icon: Icon(Icons.delete), semanticLabel: 'Delete', onPressed: null),
          ],
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.tap(find.bySemanticsLabel('Delete'), warnIfMissed: false);
    await settle(tester);
    expect(taps, 1);
  });

  testWidgets('list tiles tap', (tester) async {
    await setUpGlass(tester);
    var tapped = false;
    await tester.pumpWidget(
      scene(
        SizedBox(
          width: 320,
          child: GlassListSection(
            header: const Text('Network'),
            children: [
              GlassListTile(title: const Text('Wi-Fi'), showChevron: true, onTap: () => tapped = true),
              const GlassListTile(title: Text('Bluetooth'), trailing: Text('On')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Wi-Fi'));
    await settle(tester);
    expect(tapped, isTrue);
    expect(find.text('Network'), findsOneWidget);
  });

  testWidgets('sidebar selects by tap and arrow keys', (tester) async {
    await setUpGlass(tester, size: const Size(400, 400));
    var selected = 0;
    await tester.pumpWidget(
      scene(
        StatefulBuilder(
          builder:
              (context, setState) => GlassSidebar(
                items: const [
                  GlassSidebarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
                  GlassSidebarItem(icon: Icon(Icons.send), label: 'Sent'),
                  GlassSidebarItem(icon: Icon(Icons.delete), label: 'Trash'),
                ],
                selected: selected,
                onSelected: (i) => setState(() => selected = i),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Trash'));
    await settle(tester);
    expect(selected, 2);
    Focus.of(tester.element(find.text('Inbox'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(selected, 1);
  });

  testWidgets('dock opens items and shows a label on hover', (tester) async {
    await setUpGlass(tester, size: const Size(500, 260));
    var opened = '';
    await tester.pumpWidget(
      scene(
        GlassDock(
          items: [
            GlassDockItem(
              icon: _appIcon(Colors.blue, Colors.cyan, Icons.public),
              label: 'Safari',
              onPressed: () => opened = 'safari',
            ),
            GlassDockItem(icon: _appIcon(Colors.green, Colors.teal, Icons.message), label: 'Messages', running: true),
            GlassDockItem(icon: _appIcon(Colors.orange, Colors.red, Icons.photo), label: 'Photos'),
          ],
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Safari'));
    await settle(tester);
    expect(opened, 'safari');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.bySemanticsLabel('Messages')));
    await mouse.moveBy(const Offset(1, 0));
    await settle(tester);
    expect(find.text('Messages'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('magnifier drags and reports where it is', (tester) async {
    await setUpGlass(tester, size: const Size(400, 300));
    Offset? moved;
    await tester.pumpWidget(scene(SizedBox(width: 400, height: 300, child: GlassMagnifier(onMoved: (o) => moved = o))));
    await tester.drag(find.bySemanticsLabel('Magnifier'), const Offset(-60, 20));
    await settle(tester);
    expect(moved, isNotNull);
    expect(moved!.dx, lessThan(140));
  });

  testWidgets('magnifier', (tester) async {
    await setUpGlass(tester, size: const Size(400, 260));
    await tester.pumpWidget(
      scene(
        const SizedBox(
          width: 400,
          height: 260,
          child: GlassMagnifier(size: 150, magnification: 2, position: Offset(125, 55)),
        ),
      ),
    );
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/magnifier.png'));
  });

  for (final dark in [false, true]) {
    testWidgets('looks right ${dark ? 'dark' : 'light'}', (tester) async {
      await setUpGlass(tester, size: const Size(720, 560));
      await tester.pumpWidget(
        scene(
          dark: dark,
          SizedBox(
            width: 720,
            height: 560,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: GlassNavigationBar(
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
                ),
                Positioned(
                  left: 16,
                  top: 70,
                  child: GlassSidebar(
                    header: const Text('Mail'),
                    items: const [
                      GlassSidebarItem(icon: Icon(Icons.inbox), label: 'Inbox', trailing: Text('12')),
                      GlassSidebarItem(icon: Icon(Icons.star_border), label: 'Favourites'),
                      GlassSidebarItem(icon: Icon(Icons.send_outlined), label: 'Sent'),
                      GlassSidebarItem(icon: Icon(Icons.delete_outline), label: 'Trash'),
                    ],
                    selected: 0,
                    onSelected: (_) {},
                  ),
                ),
                Positioned(
                  left: 280,
                  right: 16,
                  top: 70,
                  child: GlassListSection(
                    header: const Text('Network'),
                    footer: const Text('Devices nearby can find this one.'),
                    children: [
                      GlassListTile(
                        leading: const Icon(Icons.wifi),
                        title: const Text('Wi-Fi'),
                        trailing: const Text('Home'),
                        showChevron: true,
                        onTap: () {},
                      ),
                      GlassListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: const Text('Bluetooth'),
                        trailing: GlassSwitch(value: true, onChanged: (_) {}),
                      ),
                      const GlassListTile(title: Text('Name'), subtitle: Text('Glisse’s phone')),
                    ],
                  ),
                ),
                Positioned(
                  left: 280,
                  top: 330,
                  child: GlassToolbar(
                    children: [
                      GlassToolbarItem(
                        icon: const Icon(Icons.format_bold),
                        semanticLabel: 'Bold',
                        selected: true,
                        onPressed: () {},
                      ),
                      GlassToolbarItem(
                        icon: const Icon(Icons.format_italic),
                        semanticLabel: 'Italic',
                        onPressed: () {},
                      ),
                      const GlassToolbarSpacer(),
                      GlassToolbarItem(icon: const Icon(Icons.undo), semanticLabel: 'Undo', onPressed: () {}),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(
                    child: GlassDock(
                      items: [
                        GlassDockItem(
                          icon: _appIcon(Colors.blue, Colors.cyan, Icons.public),
                          label: 'Safari',
                          running: true,
                        ),
                        GlassDockItem(icon: _appIcon(Colors.green, Colors.teal, Icons.message), label: 'Messages'),
                        GlassDockItem(
                          icon: _appIcon(Colors.orange, Colors.red, Icons.photo),
                          label: 'Photos',
                          running: true,
                        ),
                        GlassDockItem(icon: _appIcon(Colors.purple, Colors.pink, Icons.music_note), label: 'Music'),
                        GlassDockItem(icon: _appIcon(Colors.grey, Colors.blueGrey, Icons.settings), label: 'Settings'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.bySemanticsLabel('Photos')));
      await mouse.moveBy(const Offset(4, 0));
      await settle(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/navigation_${dark ? 'dark' : 'light'}.png'),
      );
      await mouse.removePointer();
    });
  }
}

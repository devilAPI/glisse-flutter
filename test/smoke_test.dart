// Every widget, in every theme, direction and glass mode, must build, lay out,
// paint and take a press without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

import 'helpers.dart';

List<Widget> everything() => [
  const Glass(width: 120, height: 60, child: Text('Glass')),
  GlassButton(onPressed: () {}, child: const Text('Button')),
  GlassButton(onPressed: () {}, icon: const Icon(Icons.add), semanticLabel: 'Add'),
  GlassButton(onPressed: () {}, variant: GlassButtonVariant.filled, child: const Text('Filled')),
  GlassSwitch(value: true, onChanged: (_) {}, semanticLabel: 'Wi-Fi'),
  SizedBox(width: 200, child: GlassSlider(value: 0.4, onChanged: (_) {}, semanticLabel: 'Volume')),
  SizedBox(width: 200, child: GlassSlider(value: 3, min: 3, max: 3, onChanged: (_) {}, semanticLabel: 'Fixed')),
  GlassSegmentedControl<int>(
    segments: const [GlassSegment(value: 0, label: 'A'), GlassSegment(value: 1, label: 'B')],
    value: 0,
    onChanged: (_) {},
  ),
  GlassTabBar<int>(
    items: const [
      GlassSegment(value: 0, label: 'One', icon: Icons.home),
      GlassSegment(value: 1, label: 'Two', icon: Icons.star),
    ],
    value: 1,
    onChanged: (_) {},
  ),
  GlassMenu(semanticLabel: 'More', items: [GlassMenuItem(label: const Text('Item'), onSelected: () {})]),
  const SizedBox(width: 220, child: GlassSearchField()),
  const SizedBox(width: 220, child: GlassInput(placeholder: 'Name')),
  GlassCheckbox(value: null, tristate: true, onChanged: (_) {}, semanticLabel: 'All'),
  GlassRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}, semanticLabel: 'One'),
  GlassStepper(value: 2, onChanged: (_) {}, semanticLabel: 'Guests'),
  GlassChip(label: const Text('Chip'), selected: true, onSelected: (_) {}, onDeleted: () {}),
  const SizedBox(width: 160, child: GlassProgressBar(value: 0.3)),
  const SizedBox(width: 160, child: GlassProgressBar()),
  const GlassActivityIndicator(),
  const GlassProgressRing(value: 0.5),
  const GlassPageIndicator(count: 4, page: 1.5),
  const GlassBadge(label: '3', child: Icon(Icons.mail)),
  GlassButtonGroup(
    children: [
      GlassButtonGroupItem(icon: const Icon(Icons.format_bold), onPressed: () {}, semanticLabel: 'Bold'),
      GlassButtonGroupItem(icon: const Icon(Icons.format_italic), onPressed: () {}, semanticLabel: 'Italic'),
    ],
  ),
  GlassToolbar(
    children: [
      GlassToolbarItem(icon: const Icon(Icons.undo), onPressed: () {}, semanticLabel: 'Undo'),
      GlassToolbarItem(icon: const Icon(Icons.redo), onPressed: () {}, semanticLabel: 'Redo'),
    ],
  ),
  SizedBox(
    width: 260,
    child: GlassListSection(
      header: const Text('Header'),
      children: [
        GlassListTile(title: const Text('Row'), onTap: () {}, showChevron: true),
        const GlassListTile(leading: Icon(Icons.wifi), title: Text('Wi-Fi'), subtitle: Text('Home')),
      ],
    ),
  ),
  const SizedBox(width: 300, child: GlassNavigationBar(leading: GlassBackButton(label: 'Back'), title: Text('Title'))),
  SizedBox(
    height: 160,
    child: GlassSidebar(
      items: const [
        GlassSidebarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
        GlassSidebarItem(icon: Icon(Icons.send), label: 'Sent'),
      ],
      selected: 0,
      onSelected: (_) {},
    ),
  ),
  GlassDock(
    items: [
      GlassDockItem(icon: const Icon(Icons.public), label: 'Web', onPressed: () {}),
      const GlassDockItem(icon: Icon(Icons.photo), label: 'Photos', running: true),
    ],
  ),
  const SizedBox(width: 200, height: 140, child: GlassMagnifier(size: 80)),
  GlassPopover(popoverBuilder: (_) => const Text('Popover'), child: const Text('Anchor')),
  const GlassTooltip(message: 'Tip', child: Text('Hover me')),
  GlassContextMenu(items: [GlassMenuItem(label: const Text('Copy'), onSelected: () {})], child: const Text('Hold')),
  const SizedBox(
    width: 260,
    child: GlassCard(leading: Icon(Icons.cloud), title: Text('Card'), subtitle: Text('Sub'), child: Text('Body')),
  ),
  const SizedBox(width: 260, child: GlassDisclosure(title: Text('More'), initiallyExpanded: true, child: Text('Body'))),
  const SizedBox(width: 260, child: GlassActionSheet(actions: [GlassActionSheetAction(child: Text('Share'))])),
  SizedBox(width: 260, child: GlassSlideToConfirm(onConfirmed: () {})),
  const GlassAvatar(initials: 'Ada Lovelace', status: GlassAvatarStatus.online),
  const GlassAvatarGroup(
    max: 2,
    children: [GlassAvatar(initials: 'A'), GlassAvatar(initials: 'B'), GlassAvatar(initials: 'C')],
  ),
  GlassColorSwatches(
    colors: const [Color(0xFFFF3B30), Color(0xFF34C759), Color(0xFF0088FF)],
    value: const Color(0xFF34C759),
    onChanged: (_) {},
  ),
  GlassKnob(value: 0.6, onChanged: (_) {}, semanticLabel: 'Gain'),
  SizedBox(
    width: 240,
    child: GlassRangeSlider(values: const GlassRange(0.2, 0.7), onChanged: (_) {}, semanticLabel: 'Price'),
  ),
  SizedBox(width: 160, child: GlassPicker(items: const ['One', 'Two', 'Three'], onSelectedItemChanged: (_) {})),
  SizedBox(width: 300, child: GlassDatePicker(initialDate: DateTime(2026, 2, 28), onDateTimeChanged: (_) {})),
  SizedBox(width: 220, child: GlassTimePicker(initialTime: DateTime(2026, 1, 1, 9, 41), onDateTimeChanged: (_) {})),
  GlassRating(value: 3.5, allowHalf: true, onChanged: (_) {}),
  const GlassPinField(length: 4),
  SizedBox(
    width: 320,
    child: GlassCalendar(
      selectedDate: DateTime(2026, 3, 15),
      currentDate: DateTime(2026, 3, 10),
      initialMonth: DateTime(2026, 3),
      onDateSelected: (_) {},
    ),
  ),
];

void main() {
  for (final dark in [false, true]) {
    for (final direction in TextDirection.values) {
      for (final mode in [GlassMode.auto, GlassMode.frost]) {
        testWidgets(
          'every widget builds and takes a press (${dark ? 'dark' : 'light'}, ${direction.name}, ${mode.name})',
          (tester) async {
            await setUpGlass(tester, size: const Size(900, 1400), ratio: 1);
            final widgets = everything();
            await tester.pumpWidget(
              scene(
                dark: dark,
                GlassTheme(
                  data: (dark ? GlassThemeData.dark() : GlassThemeData.light()).copyWith(mode: mode),
                  child: Directionality(
                    textDirection: direction,
                    child: SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: widgets)),
                  ),
                ),
              ),
            );
            await settle(tester);
            expect(tester.takeException(), isNull);
            // Press and release in the middle of each, as a finger would.
            for (var i = 0; i < widgets.length; i++) {
              final finder = find.byWidget(widgets[i]);
              if (finder.evaluate().isEmpty) continue;
              final gesture = await tester.startGesture(tester.getCenter(finder));
              await tester.pump(const Duration(milliseconds: 50));
              await gesture.moveBy(const Offset(6, 0));
              await tester.pump(const Duration(milliseconds: 50));
              await gesture.up();
              await tester.pump(const Duration(milliseconds: 50));
            }
            await settle(tester);
            // Close anything a press opened.
            await tester.tapAt(const Offset(5, 5));
            await settle(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('tiny and zero sizes do not throw', (tester) async {
    await setUpGlass(tester, size: const Size(400, 400), ratio: 3);
    await tester.pumpWidget(
      scene(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Glass(width: 0, height: 0),
            Glass(width: 1, height: 1),
            Glass(width: 2, height: 300, borderRadius: double.infinity),
            SizedBox(width: 0, child: GlassProgressBar(value: 0.5)),
            SizedBox(width: 10, child: GlassSearchField()),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass outside any backdrop and before the shader loads frosts', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: Center(child: Glass(width: 100, height: 50))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

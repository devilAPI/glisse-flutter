# Widget catalogue

Every widget in `package:glisse`, with a minimal example. Each control:

- takes a `semanticLabel`, a `focusNode` and `autofocus`;
- answers the keyboard;
- mirrors under right-to-left text;
- lands at once when the platform asks for reduced motion.

A control whose callback is null is disabled.

The [live gallery](https://devilapi.github.io/glisse-flutter/) shows them all, and the [API reference](https://devilapi.github.io/glisse-flutter/api/) lists every parameter.

Contents: [Glass](#glass) · [Buttons](#buttons) · [Toggles and values](#toggles-and-values) · [Pickers](#pickers) · [Text](#text) · [Status](#status) · [Navigation](#navigation) · [Lists and surfaces](#lists-and-surfaces) · [Overlays](#overlays) · [Lenses](#lenses) · [Building blocks](#building-blocks)

## Glass

### `Glass`

A pane of Liquid Glass. It bends what's behind it at the rim, frosts and tints it, lights its edge, and shows its child on top. Its radius is `double.infinity` for a capsule.

```dart
Glass(
  borderRadius: 28,
  padding: const EdgeInsets.all(20),
  child: const Text('Hello, glass'),
)
```

### `GlassBackdrop`

This is what glass refracts on every renderer. Put the page's background in `background` and the glass in `child`; glass anywhere under `child` bends a copy of the background. On Impeller, glass also bends the live page without one.

```dart
GlassBackdrop(
  background: Image.asset('wallpaper.jpg', fit: BoxFit.cover),
  child: const Center(child: Glass(width: 200, height: 120)),
)
```

## Buttons

### `GlassButton`

The iOS 26 glass button: it swells and stretches under a finger. It comes as glass or filled, and can be tinted, destructive or icon-only.

```dart
GlassButton(
  variant: GlassButtonVariant.filled,
  icon: const Icon(Icons.send),
  onPressed: () {},
  child: const Text('Send'),
)
```

An icon-only button is a circle; give it a label:

```dart
GlassButton(icon: const Icon(Icons.add), semanticLabel: 'Add', onPressed: () {})
```

### `GlassButtonGroup`

Buttons joined on one capsule, such as text formatting.

```dart
GlassButtonGroup(children: [
  GlassButtonGroupItem(icon: const Icon(Icons.format_bold), semanticLabel: 'Bold', selected: bold, onPressed: () {}),
  GlassButtonGroupItem(icon: const Icon(Icons.format_italic), semanticLabel: 'Italic', onPressed: () {}),
])
```

### `GlassSlideToConfirm`

A knob you slide to the end to confirm, for payments and other actions you can't undo.

```dart
GlassSlideToConfirm(
  label: 'Slide to pay',
  resetAfter: const Duration(seconds: 2),
  onConfirmed: () {},
)
```

## Toggles and values

### `GlassSwitch`

A white knob that lifts into a lens while held and bends the track under its rim. You can tap it or drag it across.

```dart
GlassSwitch(value: on, semanticLabel: 'Wi-Fi', onChanged: (v) => setState(() => on = v))
```

### `GlassCheckbox` and `GlassRadio`

The box fills with the accent and draws its tick in. With `tristate`, a null value shows a dash.

```dart
GlassCheckbox(value: checked, semanticLabel: 'Remember me', onChanged: (v) => setState(() => checked = v!))
```

```dart
GlassRadio<String>(value: 'm', groupValue: size, semanticLabel: 'Medium', onChanged: (v) => setState(() => size = v))
```

### `GlassSlider`

The thumb lifts into a magnifying lens over a thicker version of the track. `divisions` snaps it to steps.

```dart
GlassSlider(value: volume, semanticLabel: 'Volume', onChanged: (v) => setState(() => volume = v))
```

### `GlassRangeSlider`

Two knobs on one rail. The knob nearer the finger moves, and the two never cross.

```dart
GlassRangeSlider(
  values: range,
  min: 0,
  max: 100,
  divisions: 20,
  semanticLabel: 'Price',
  onChanged: (v) => setState(() => range = v),
)
```

### `GlassStepper`

A − / + capsule. A held half repeats, faster the longer it's held.

```dart
GlassStepper(value: guests, min: 1, max: 12, semanticLabel: 'Guests', onChanged: (v) => setState(() => guests = v))
```

### `GlassKnob`

A rotary dial with a 270° arc. Drag it up and down or round, or use the scroll wheel or the arrow keys.

```dart
GlassKnob(
  value: gain,
  divisions: 20,
  semanticLabel: 'Gain',
  onChanged: (v) => setState(() => gain = v),
  child: Text('${(gain * 100).round()}'),
)
```

### `GlassRating`

Stars you can tap or drag across, with half stars if you like. With a null callback it's read-only, and shows fractions such as 4.3.

```dart
GlassRating(value: stars, allowHalf: true, semanticLabel: 'Rating', onChanged: (v) => setState(() => stars = v))
```

### `GlassSegmentedControl`

A thumb on a glass track. While held or dragged it lifts into a lens over the labels.

```dart
GlassSegmentedControl<String>(
  segments: const [GlassSegment(value: 'day', label: 'Day'), GlassSegment(value: 'week', label: 'Week')],
  value: view,
  onChanged: (v) => setState(() => view = v),
)
```

### `GlassChip`

A filter chip, which can be selected or deleted.

```dart
GlassChip(label: const Text('Travel'), selected: travel, onSelected: (v) => setState(() => travel = v))
```

## Pickers

### `GlassPicker`

An iOS wheel. The row under the glass band is the one chosen.

```dart
GlassPicker(
  items: const ['Apple', 'Banana', 'Cherry'],
  semanticLabel: 'Fruit',
  onSelectedItemChanged: (i) => setState(() => fruit = i),
)
```

### `GlassDatePicker` and `GlassTimePicker`

Month, day and year wheels, or hour, minute and AM/PM wheels, on one pane. The day keeps within the month.

```dart
GlassDatePicker(initialDate: DateTime(2026, 6, 15), onDateTimeChanged: (d) => setState(() => date = d))
```

```dart
GlassTimePicker(use24hFormat: true, minuteInterval: 5, onDateTimeChanged: (t) => setState(() => time = t))
```

### `GlassCalendar`

A month grid. Today is outlined, and the selected day fills with the accent. Swipe or use the chevrons to change month, and set `firstDate` and `lastDate` to bound it.

```dart
GlassCalendar(
  selectedDate: date,
  firstDate: DateTime(2026),
  lastDate: DateTime(2027, 12, 31),
  onDateSelected: (d) => setState(() => date = d),
)
```

### `GlassColorSwatches`

Round swatches. The chosen one springs up inside a ring.

```dart
GlassColorSwatches(
  colors: const [Color(0xFFFF3B30), Color(0xFF34C759), Color(0xFF0088FF)],
  labels: const ['Red', 'Green', 'Blue'],
  value: accent,
  onChanged: (c) => setState(() => accent = c),
)
```

## Text

### `GlassInput` and `GlassSearchField`

Text fields on glass. The search field has a clear button.

```dart
const GlassInput(placeholder: 'Name', clearable: true)
```

```dart
GlassSearchField(onChanged: (q) => setState(() => query = q))
```

### `GlassPinField`

One glass box per character of a one-time code. It takes a pasted code, and shakes red when `error` is set.

```dart
GlassPinField(length: 6, error: wrongCode, onCompleted: (code) {})
```

## Status

### `GlassProgressBar`, `GlassProgressRing` and `GlassActivityIndicator`

A null value makes the bar indeterminate.

```dart
GlassProgressBar(value: progress)
```

```dart
GlassProgressRing(value: progress, child: Text('${(progress * 100).round()}'))
```

```dart
const GlassActivityIndicator()
```

### `GlassBadge`

A count or a dot on the corner of its child.

```dart
const GlassBadge(label: '3', child: Icon(Icons.mail))
```

### `GlassPageIndicator`

Page dots that follow a fractional page while you swipe.

```dart
GlassPageIndicator(count: 4, page: page, onTap: (i) {})
```

### `GlassAvatar` and `GlassAvatarGroup`

Shows a photo, initials or an icon, with an optional status dot. A group overlaps its avatars and ends with "+N".

```dart
const GlassAvatar(initials: 'Ada Lovelace', status: GlassAvatarStatus.online)
```

```dart
const GlassAvatarGroup(max: 3, children: [
  GlassAvatar(initials: 'AL'),
  GlassAvatar(initials: 'GH'),
  GlassAvatar(initials: 'KJ'),
  GlassAvatar(initials: 'MH'),
])
```

## Navigation

### `GlassTabBar`

Tabs on glass, with or without icons. The selection springs between tabs, follows a drag, and lifts into a lens that splits the colours of the labels at its rim.

```dart
GlassTabBar<int>(
  items: const [
    GlassSegment(value: 0, label: 'Home', icon: Icons.home),
    GlassSegment(value: 1, label: 'Search', icon: Icons.search),
  ],
  value: tab,
  onChanged: (v) => setState(() => tab = v),
)
```

### `GlassNavigationBar` and `GlassBackButton`

A floating top bar with a title, a back button and actions.

```dart
GlassNavigationBar(
  leading: GlassBackButton(label: 'Settings', onPressed: () {}),
  title: const Text('Wi-Fi'),
  actions: [GlassButton(icon: const Icon(Icons.add), semanticLabel: 'Add', onPressed: () {})],
)
```

### `GlassToolbar`

A floating row (or column) of icon buttons.

```dart
GlassToolbar(children: [
  GlassToolbarItem(icon: const Icon(Icons.undo), semanticLabel: 'Undo', onPressed: () {}),
  const GlassToolbarSpacer(),
  GlassToolbarItem(icon: const Icon(Icons.redo), semanticLabel: 'Redo', onPressed: () {}),
])
```

### `GlassSidebar`

A glass sidebar for wide layouts.

```dart
GlassSidebar(
  items: const [
    GlassSidebarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
    GlassSidebarItem(icon: Icon(Icons.send), label: 'Sent'),
  ],
  selected: folder,
  onSelected: (i) => setState(() => folder = i),
)
```

### `GlassDock`

A macOS-style dock whose icons magnify under the pointer.

```dart
GlassDock(items: [
  GlassDockItem(icon: const Icon(Icons.public), label: 'Web', running: true, onPressed: () {}),
  GlassDockItem(icon: const Icon(Icons.photo), label: 'Photos', onPressed: () {}),
])
```

## Lists and surfaces

### `GlassListSection` and `GlassListTile`

An inset grouped list, like the iOS settings. The hairlines between rows start where the text does.

```dart
GlassListSection(header: const Text('Network'), children: [
  GlassListTile(leading: const Icon(Icons.wifi), title: const Text('Wi-Fi'), showChevron: true, onTap: () {}),
  const GlassListTile(title: Text('Name'), trailing: Text('Home')),
])
```

### `GlassCard`

A padded glass panel with an optional header row. With `onTap` it presses like a button.

```dart
GlassCard(
  leading: const Icon(Icons.battery_full),
  title: const Text('Battery'),
  subtitle: const Text('Charged to 100%'),
  onTap: () {},
  child: const Text('Health is good.'),
)
```

### `GlassDisclosure`

An expanding section: the chevron turns and the body springs open. Set `inset: false` to use it as a row of a `GlassListSection`.

```dart
const GlassDisclosure(title: Text('Advanced'), child: Text('Proxy, DNS and a private address.'))
```

## Overlays

Overlays carry the page's theme and backdrop with them, so their glass bends the page beneath.

### `showGlassDialog` and `GlassAlertDialog`

An alert. Each action returns its `result`.

```dart
showGlassDialog<bool>(
  context: context,
  builder: (context) => const GlassAlertDialog(
    title: Text('Delete this photo?'),
    actions: [
      GlassDialogAction(result: false, child: Text('Cancel')),
      GlassDialogAction(result: true, destructive: true, child: Text('Delete')),
    ],
  ),
)
```

### `showGlassActionSheet`

An iOS action sheet. You can drag across the rows and let go on one.

```dart
showGlassActionSheet<String>(
  context: context,
  title: const Text('Sunset at the pier'),
  actions: const [
    GlassActionSheetAction(result: 'share', child: Text('Share…')),
    GlassActionSheetAction(result: 'delete', destructive: true, child: Text('Delete Photo')),
  ],
  cancel: const GlassActionSheetAction(child: Text('Cancel')),
)
```

### `showGlassSheet`

A floating sheet you drag down to dismiss.

```dart
showGlassSheet<void>(context: context, builder: (context) => const Text('Share'))
```

### `showGlassToast` and `showGlassBanner`

A short message at the bottom, or a notification that drops in from the top. Swipe a banner up to dismiss it. Both return a controller with `dismiss()`.

```dart
showGlassToast(context, message: const Text('Copied'), icon: const Icon(Icons.check_circle))
```

```dart
showGlassBanner(
  context: context,
  leading: const Icon(Icons.message),
  title: const Text('Messages'),
  message: const Text('Are we still on for dinner?'),
  onTap: () {},
)
```

### `GlassMenu`

A glass button that morphs into a menu. Drag to a row and let go to choose it.

```dart
GlassMenu(semanticLabel: 'More', items: [
  GlassMenuItem(label: const Text('Copy'), icon: const Icon(Icons.copy), onSelected: () {}),
  const GlassMenuSeparator(),
  GlassMenuItem(label: const Text('Delete'), destructive: true, onSelected: () {}),
])
```

### `GlassContextMenu`

Long-press, or right-click, to lift a preview of the child over a blurred page, with a menu beside it.

```dart
GlassContextMenu(
  items: [GlassMenuItem(label: const Text('Share'), icon: const Icon(Icons.ios_share), onSelected: () {})],
  child: Image.asset('photo.jpg', width: 160),
)
```

### `GlassPopover` and `GlassTooltip`

A glass bubble anchored to its child, and a tooltip on hover or long-press.

```dart
GlassPopover(
  popoverBuilder: (context) => const Text('Saved to Photos'),
  child: const Icon(Icons.info_outline),
)
```

```dart
const GlassTooltip(message: 'Share', child: Icon(Icons.ios_share))
```

## Lenses

### `GlassMagnifier`

A draggable magnifying lens over its child.

```dart
const GlassMagnifier(size: 140, magnification: 1.8, child: Text('Small print'))
```

### `GlassLoupeRegion`

A loupe that rises above the finger on a long press, as iOS shows over text.

```dart
const GlassLoupeRegion(child: Text('Press and hold to look closer'))
```

## Building blocks

These are for widgets of your own:

- **`GlassTheme`**, **`GlassThemeData`** and **`GlassBrightness`**: the tokens and tuning (see [theming](theming.md)).
- **`LiquidGlassBox`** and **`GlassStyle`**: the raw glass render object, for any shape of glass.
- **`GlassPressable`**: Glisse's press physics, with the swell and stretch under a finger, for any child.
- **`GlassSpring`**: the analytic spring every widget moves with.
- **`GlassShaders`**: the shader loader. Call `await GlassShaders.precache()` in `main` to warm it up before the first frame.
- **`HitPadding`**: grows a small control's touch target without changing its layout.

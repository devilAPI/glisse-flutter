import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse/glisse.dart';

Widget stripes() => CustomPaint(painter: _Stripes(), size: Size.infinite);

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF7E0));
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 10, size.height), Paint()..color = const Color(0xFF2050D0));
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 6), Paint()..color = const Color(0xFFE03030));
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

void main() {
  testWidgets('glass over a backdrop', (tester) async {
    await tester.runAsync(() => GlassShaders.load());
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: GlassBackdrop(
        background: stripes(),
        child: const Center(child: Glass(width: 260, height: 120, borderRadius: 40)),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(GlassBackdrop), matchesGoldenFile('goldens/glass_smoke.png'));
  });
}

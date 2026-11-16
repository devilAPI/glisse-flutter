// Frame timings while scrolling the gallery over its animated wallpaper:
//   flutter test integration_test/perf_test.dart --profile -d linux
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glisse_example/main.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling the gallery', (tester) async {
    app.main();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final list = find.byWidgetPredicate((w) => w is ListView && w.controller != null).first;
    await binding.watchPerformance(() async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -500), 1500);
        await tester
            .pumpAndSettle(
              const Duration(milliseconds: 16),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 5),
            )
            .catchError((_) => 0);
      }
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, 500), 1500);
        await tester
            .pumpAndSettle(
              const Duration(milliseconds: 16),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 5),
            )
            .catchError((_) => 0);
      }
    }, reportKey: 'scrolling');
    // ignore: avoid_print
    print('PERF ${binding.reportData}');
  });
}

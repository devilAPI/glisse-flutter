import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens are rendered on a developer's machine. On CI, where the GPU-less
/// rasteriser and fonts can differ by a few pixels, a small difference passes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.environment['CI'] == 'true' && goldenFileComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${(goldenFileComparator as LocalFileComparator).basedir}test.dart'),
      tolerance: 0.03,
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

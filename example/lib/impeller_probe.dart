import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:glisse/glisse.dart';

// Glass in every mode over stripes, to check each path on a device.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlassShaders.precache();
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)), child: child!),
      home: const Probe()));
}

class Probe extends StatelessWidget {
  const Probe({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, Widget glass) => Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            SizedBox(
                width: 60,
                child: Text(label, style: const TextStyle(color: Colors.black, backgroundColor: Colors.white))),
            Container(decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 1)), child: glass),
          ]),
        );
    return GlassBackdrop(
      background: CustomPaint(painter: _Stripes()),
      child: SafeArea(
        child: Wrap(children: [
          tile('box', const SizedBox(width: 120, height: 60, child: ColoredBox(color: Color(0x80FFFFFF)))),
          tile(
              'blur',
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: const SizedBox(width: 120, height: 60)),
              )),
          tile('shader', const SizedBox(width: 120, height: 60, child: CustomPaint(painter: _ShaderTile()))),
          tile('frost', const Glass(width: 120, height: 60, borderRadius: 30, mode: GlassMode.frost)),
          tile('captured', const Glass(width: 120, height: 60, borderRadius: 30, mode: GlassMode.captured)),
          tile('live', const Glass(width: 120, height: 60, borderRadius: 30, mode: GlassMode.backdropFilter)),
          Text('filter: ${ui.ImageFilter.isShaderFilterSupported} shader: ${GlassShaders.program != null}',
              style: const TextStyle(color: Colors.black, backgroundColor: Colors.white)),
        ]),
      ),
    );
  }
}

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

class _ShaderTile extends CustomPainter {
  const _ShaderTile();

  @override
  void paint(Canvas canvas, Size size) {
    final program = GlassShaders.program;
    if (program == null) return;
    final shader = program.fragmentShader();
    for (var i = 0; i < 62; i++) {
      shader.setFloat(i, 0);
    }
    // uRect, uShape, uTint red, uLightC.w = pixel size.
    shader.setFloat(2, 0);
    shader.setFloat(3, 0);
    shader.setFloat(4, size.width);
    shader.setFloat(5, size.height);
    shader.setFloat(6, size.width);
    shader.setFloat(7, size.height);
    shader.setFloat(8, 20);
    shader.setFloat(42 + 3, 1); // tint alpha (premultiplied red below)
    shader.setFloat(42, 1);
    shader.setFloat(41, 0.33);
    shader.setFloat(27, 1); // saturation
    shader.setFloat(28, 1); // brightness
    final recorder = ui.PictureRecorder();
    Canvas(recorder);
    shader.setImageSampler(0, recorder.endRecording().toImageSync(1, 1));
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderTile oldDelegate) => false;
}

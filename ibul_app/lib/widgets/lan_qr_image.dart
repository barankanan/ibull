import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Draws the pairing payload already shown as text. No network call.
class LanQrImage extends StatelessWidget {
  const LanQrImage({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(painter: _LanQrPainter(image)),
    );
  }
}

class _LanQrPainter extends CustomPainter {
  _LanQrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final cell = size.width / count;
    final paint = Paint()..color = const Color(0xFF111111);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (!image.isDark(y, x)) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LanQrPainter oldDelegate) =>
      oldDelegate.image != image;
}

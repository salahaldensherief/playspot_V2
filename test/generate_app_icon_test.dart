import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate PlaySpot Enlarged Wordmark App Icon PNGs', () async {
    // Load Orbitron font
    final fontLoader = FontLoader('Orbitron');
    final fontData = File('assets/fonts/Orbitron/Orbitron-Bold.ttf').readAsBytesSync();
    fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    const double size = 1024.0;
    const neonCyan = Color(0xFF00E5FF);
    const white = Color(0xFFFFFFFF);
    const darkBg = Color(0xFF070A10);

    void drawWordmarkIcon(Canvas canvas, Size canvasSize, {required bool isForegroundOnly}) {
      if (!isForegroundOnly) {
        // Full bleed solid dark background (NO rounded corners pre-cut)
        final bgPaint = Paint()..color = darkBg;
        canvas.drawRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height), bgPaint);

        // Subtle center glow
        final radialGlow = Paint()
          ..shader = ui.Gradient.radial(
            Offset(canvasSize.width / 2, canvasSize.height / 2),
            450,
            [
              const Color(0x2200E5FF),
              const Color(0x00000000),
            ],
          );
        canvas.drawCircle(Offset(canvasSize.width / 2, canvasSize.height / 2), 450, radialGlow);
      }

      // ENLARGED Text style for "PlaySp" and "t"
      const textStyle = TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 165, // Significantly larger font size
        fontWeight: FontWeight.w900,
        color: white,
        letterSpacing: 2,
      );

      final textPainterPlaySp = TextPainter(
        text: const TextSpan(text: 'PlaySp', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPainterT = TextPainter(
        text: const TextSpan(text: 't', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // Scaled up Joystick dimensions
      const double joystickWidth = 180.0;
      const double spacing = 10.0;

      final double totalWidth = textPainterPlaySp.width + spacing + joystickWidth + spacing + textPainterT.width;
      final double startX = (canvasSize.width - totalWidth) / 2;
      final double centerY = canvasSize.height / 2;
      final double textY = centerY - (textPainterPlaySp.height / 2);

      // Draw "PlaySp"
      textPainterPlaySp.paint(canvas, Offset(startX, textY));

      // Draw Joystick Icon (Replacing 'O')
      final double joystickX = startX + textPainterPlaySp.width + spacing;
      final double joystickCenterY = centerY + 14;

      final strokePaint = Paint()
        ..color = neonCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final fillCyan = Paint()
        ..color = neonCyan
        ..style = PaintingStyle.fill;

      // Base Box
      double bw = 150;
      double bh = 80;
      double bx = joystickX + 12;
      double by = joystickCenterY;

      final RRect baseRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(20),
      );
      canvas.drawRRect(baseRRect, strokePaint);

      // Button on Base
      canvas.drawCircle(Offset(bx + bw - 30, by + bh / 2), 9.0, fillCyan);

      // Joystick Shaft
      final double shaftX = bx + bw / 2 - 12;
      final double shaftBottomY = by;
      final double shaftTopY = by - 65;
      canvas.drawLine(
        Offset(shaftX, shaftBottomY),
        Offset(shaftX, shaftTopY),
        strokePaint..strokeWidth = 14.0,
      );

      // Joystick Ball Top
      const double ballRadius = 34.0;
      final Offset ballCenter = Offset(shaftX, shaftTopY - ballRadius + 6);
      canvas.drawCircle(ballCenter, ballRadius, strokePaint..strokeWidth = 12.0);
      canvas.drawCircle(ballCenter, ballRadius - 6, fillCyan);

      // Draw "t"
      final double tX = joystickX + joystickWidth + spacing;
      textPainterT.paint(canvas, Offset(tX, textY));
    }

    // Generate app_icon.png
    final rec1 = ui.PictureRecorder();
    final canvas1 = Canvas(rec1, const Rect.fromLTWH(0, 0, size, size));
    drawWordmarkIcon(canvas1, const Size(size, size), isForegroundOnly: false);
    final img1 = await rec1.endRecording().toImage(1024, 1024);
    final bytes1 = await img1.toByteData(format: ui.ImageByteFormat.png);
    File('assets/images/app_icon.png').writeAsBytesSync(bytes1!.buffer.asUint8List());

    // Generate app_icon_foreground.png
    final rec2 = ui.PictureRecorder();
    final canvas2 = Canvas(rec2, const Rect.fromLTWH(0, 0, size, size));
    drawWordmarkIcon(canvas2, const Size(size, size), isForegroundOnly: true);
    final img2 = await rec2.endRecording().toImage(1024, 1024);
    final bytes2 = await img2.toByteData(format: ui.ImageByteFormat.png);
    File('assets/images/app_icon_foreground.png').writeAsBytesSync(bytes2!.buffer.asUint8List());

    print('SUCCESS_GENERATING_ENLARGED_WORDMARK');
  });
}

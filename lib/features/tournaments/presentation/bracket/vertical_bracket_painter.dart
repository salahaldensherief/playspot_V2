import 'package:flutter/material.dart';
import '../../domain/entities/tournament_entity.dart';

class VerticalBracketPainter extends CustomPainter {
  final List<List<TournamentMatchEntity>> rounds;
  final double matchWidth;
  final double matchHeight;
  final double horizontalGap;
  final double verticalGap;
  final double topOffset;
  final Color lineColor;

  VerticalBracketPainter({
    required this.rounds,
    required this.matchWidth,
    required this.matchHeight,
    required this.horizontalGap,
    required this.verticalGap,
    required this.topOffset,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (rounds.isEmpty) return;

    final maxCols = rounds.first.length;
    final totalWidth = maxCols * (matchWidth + horizontalGap);
    final actualWidth = size.width > 0 ? size.width : totalWidth;

    for (int r = 0; r < rounds.length - 1; r++) {
      final currMatches = rounds[r];
      final nextMatches = rounds[r + 1];

      final currY = topOffset + r * (matchHeight + verticalGap) + matchHeight;
      final nextY = topOffset + (r + 1) * (matchHeight + verticalGap);
      final midY = (currY + nextY) / 2;

      for (int i = 0; i < nextMatches.length; i++) {
        final idx1 = i * 2;
        final idx2 = idx1 + 1;

        if (idx1 >= currMatches.length) continue;

        final currColWidth = actualWidth / currMatches.length;
        final nextColWidth = actualWidth / nextMatches.length;

        final x1 = currColWidth * idx1 + currColWidth / 2;
        final has2 = idx2 < currMatches.length;
        final x2 = has2 ? currColWidth * idx2 + currColWidth / 2 : x1;
        final xNext = nextColWidth * i + nextColWidth / 2;

        // الخطوط الرأسية والأفقية لتوصيل المباريات رأسياً
        canvas.drawLine(Offset(x1, currY), Offset(x1, midY), paint);
        if (has2) {
          canvas.drawLine(Offset(x2, currY), Offset(x2, midY), paint);
          canvas.drawLine(Offset(x1, midY), Offset(x2, midY), paint);
        }
        canvas.drawLine(Offset(xNext, midY), Offset(xNext, nextY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

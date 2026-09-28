import 'package:flutter/material.dart';
import 'bracket_layout.dart';

class SplitBracketPainter extends CustomPainter {
  final BracketLayout leftLayout;
  final BracketLayout rightLayout;
  final double columnWidth;
  final double horizontalGap;
  final double matchHeight;
  final double topOffset;
  final double centerColX;
  final double finalCenterY; // بالنسبة لبداية المحتوى (بدون topOffset)
  final Color lineColor;

  static const double _avatarRadius = 24.0;
  static const double _mergeGap = 10.0;

  SplitBracketPainter({
    required this.leftLayout,
    required this.rightLayout,
    required this.columnWidth,
    required this.horizontalGap,
    required this.matchHeight,
    required this.topOffset,
    required this.centerColX,
    required this.finalCenterY,
    required this.lineColor,
  });

  double _y(double centerY) => topOffset + centerY;
  double _avatarTop(double centerY) => _y(centerY) - matchHeight / 2 + _avatarRadius;
  double _avatarBottom(double centerY) => _y(centerY) + matchHeight / 2 - _avatarRadius;

  double _mergeAtCol(Canvas canvas, Paint paint, double colX, double centerY, {required bool toRight}) {
    final centerX = colX + columnWidth / 2;
    final edgeX = toRight ? centerX + _avatarRadius : centerX - _avatarRadius;
    final mergeX = toRight ? edgeX + _mergeGap : edgeX - _mergeGap;
    final topY = _avatarTop(centerY);
    final bottomY = _avatarBottom(centerY);

    canvas.drawLine(Offset(edgeX, topY), Offset(mergeX, topY), paint);
    canvas.drawLine(Offset(edgeX, bottomY), Offset(mergeX, bottomY), paint);
    canvas.drawLine(Offset(mergeX, topY), Offset(mergeX, bottomY), paint);
    return mergeX;
  }

  void _connectRound(
      Canvas canvas,
      Paint paint,
      BracketLayout layout,
      int roundIndex,
      double currColX,
      double nextColX, {
        required bool toRight,
      }) {
    final curr = layout.centersY[roundIndex];
    final next = layout.centersY[roundIndex + 1];

    for (int i = 0; i < next.length; i++) {
      final mergeA = _mergeAtCol(canvas, paint, currColX, curr[i * 2], toRight: toRight);
      final hasB = i * 2 + 1 < curr.length;
      final mergeB = hasB ? _mergeAtCol(canvas, paint, currColX, curr[i * 2 + 1], toRight: toRight) : mergeA;

      final yA = _y(curr[i * 2]);
      final yB = hasB ? _y(curr[i * 2 + 1]) : yA;
      final yNext = _y(next[i]);
      final nextEdge = toRight ? nextColX : nextColX + columnWidth;
      final midX = (mergeA + nextEdge) / 2;

      canvas.drawLine(Offset(mergeA, yA), Offset(midX, yA), paint);
      if (hasB) {
        canvas.drawLine(Offset(mergeB, yB), Offset(midX, yB), paint);
        canvas.drawLine(Offset(midX, yA), Offset(midX, yB), paint);
      }
      canvas.drawLine(Offset(midX, yNext), Offset(nextEdge, yNext), paint);
    }
  }

  void _connectToFinal(
      Canvas canvas,
      Paint paint,
      BracketLayout layout,
      double lastColX, {
        required bool toRight,
        required bool enterTop,
      }) {
    if (layout.rounds.isEmpty) return;
    final last = layout.centersY.last;
    final finalAvatarY = enterTop
        ? topOffset + finalCenterY - matchHeight / 2 + _avatarRadius
        : topOffset + finalCenterY + matchHeight / 2 - _avatarRadius;
    final centerEdge = toRight ? centerColX : centerColX + columnWidth;

    for (final centerY in last) {
      final mergeX = _mergeAtCol(canvas, paint, lastColX, centerY, toRight: toRight);
      final y = _y(centerY);
      final midX = (mergeX + centerEdge) / 2;
      canvas.drawLine(Offset(mergeX, y), Offset(midX, y), paint);
      canvas.drawLine(Offset(midX, y), Offset(midX, finalAvatarY), paint);
      canvas.drawLine(Offset(midX, finalAvatarY), Offset(centerEdge, finalAvatarY), paint);
    }
  }

  // X-position لعمود الفرع اليمين حسب رقم الدور (k=0 هو دور فيه أكتر مباريات)
  double _rightColX(int roundIndex, int rightCount, double rightStartX) =>
      rightStartX + (rightCount - 1 - roundIndex) * (columnWidth + horizontalGap);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // ================= الفرع الأيسر: بيتحرك يمين ناحية النص =================
    for (int r = 0; r < leftLayout.rounds.length - 1; r++) {
      final currColX = 20 + r * (columnWidth + horizontalGap);
      final nextColX = 20 + (r + 1) * (columnWidth + horizontalGap);
      _connectRound(canvas, paint, leftLayout, r, currColX, nextColX, toRight: true);
    }
    if (leftLayout.rounds.isNotEmpty) {
      final lastColX = 20 + (leftLayout.rounds.length - 1) * (columnWidth + horizontalGap);
      _connectToFinal(canvas, paint, leftLayout, lastColX, toRight: true, enterTop: true);
    }

    // ================= الفرع الأيمن: بيتحرك شمال ناحية النص =================
    final rightStartX = centerColX + columnWidth + horizontalGap;
    final rightCount = rightLayout.rounds.length;

    for (int k = 0; k < rightCount - 1; k++) {
      final currColX = _rightColX(k, rightCount, rightStartX);
      final nextColX = _rightColX(k + 1, rightCount, rightStartX);
      _connectRound(canvas, paint, rightLayout, k, currColX, nextColX, toRight: false);
    }
    if (rightLayout.rounds.isNotEmpty) {
      final lastColX = _rightColX(rightCount - 1, rightCount, rightStartX); // = rightStartX
      _connectToFinal(canvas, paint, rightLayout, lastColX, toRight: false, enterTop: false);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
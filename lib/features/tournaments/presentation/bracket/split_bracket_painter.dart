import 'package:flutter/material.dart';
import '../../domain/entities/tournament_entity.dart';

class SplitBracketPainter extends CustomPainter {
  final List<List<TournamentMatchEntity>> leftRounds;
  final List<List<TournamentMatchEntity>> rightRounds;
  final double columnWidth;
  final double horizontalGap;
  final double matchHeight;
  final double verticalGap;
  final double branchHeight;
  final Color lineColor;

  // نص قطر صورة اللاعب - لازم يفضل متطابق مع حجم الأفاتار (36) في BracketMatchNode
  static const double _avatarRadius = 18.0;
  static const double _mergeGap = 10.0;

  SplitBracketPainter({
    required this.leftRounds,
    required this.rightRounds,
    required this.columnWidth,
    required this.horizontalGap,
    required this.matchHeight,
    required this.verticalGap,
    required this.branchHeight,
    required this.lineColor,
  });

  double _topY(int index, int count) {
    final slot = branchHeight / count;
    return 40 + slot * index + (slot - matchHeight) / 2;
  }

  double _centerY(int index, int count) => _topY(index, count) + matchHeight / 2;
  double _avatarTopY(int index, int count) => _topY(index, count) + _avatarRadius;
  double _avatarBottomY(int index, int count) => _topY(index, count) + matchHeight - _avatarRadius;

  /// يرسم الخط القصير اللي بيوحّد صورتي اللاعبين في نقطة واحدة (mergeX)
  /// عشان الخط الأساسي يبان طالع من الصور فعلاً.
  double _drawAvatarMerge(
    Canvas canvas,
    Paint paint,
    double colX,
    int index,
    int count, {
    required bool toRight,
  }) {
    final centerX = colX + columnWidth / 2;
    final edgeX = toRight ? centerX + _avatarRadius : centerX - _avatarRadius;
    final mergeX = toRight ? edgeX + _mergeGap : edgeX - _mergeGap;
    final topY = _avatarTopY(index, count);
    final bottomY = _avatarBottomY(index, count);

    canvas.drawLine(Offset(edgeX, topY), Offset(mergeX, topY), paint);
    canvas.drawLine(Offset(edgeX, bottomY), Offset(mergeX, bottomY), paint);
    canvas.drawLine(Offset(mergeX, topY), Offset(mergeX, bottomY), paint);
    return mergeX;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double startX = 10;
    final double centerColX = startX + leftRounds.length * (columnWidth + horizontalGap);
    final double finalTopY = branchHeight / 2 - matchHeight / 2 + 20;

    // ================= الفرع الأيسر (يتجه يمين ناحية الكأس) =================
    for (int r = 0; r < leftRounds.length - 1; r++) {
      final curr = leftRounds[r];
      final next = leftRounds[r + 1];
      final colX = startX + r * (columnWidth + horizontalGap);
      final nextColX = startX + (r + 1) * (columnWidth + horizontalGap);

      for (int i = 0; i < next.length; i++) {
        final mergeA = _drawAvatarMerge(canvas, paint, colX, i * 2, curr.length, toRight: true);
        final hasB = i * 2 + 1 < curr.length;
        final mergeB = hasB
            ? _drawAvatarMerge(canvas, paint, colX, i * 2 + 1, curr.length, toRight: true)
            : mergeA;

        final yA = _centerY(i * 2, curr.length);
        final yB = hasB ? _centerY(i * 2 + 1, curr.length) : yA;
        final yNext = _centerY(i, next.length);
        final midX = (mergeA + nextColX) / 2;

        canvas.drawLine(Offset(mergeA, yA), Offset(midX, yA), paint);
        if (hasB) {
          canvas.drawLine(Offset(mergeB, yB), Offset(midX, yB), paint);
          canvas.drawLine(Offset(midX, yA), Offset(midX, yB), paint);
        }
        canvas.drawLine(Offset(midX, yNext), Offset(nextColX, yNext), paint);
      }
    }

    // وصلة آخر عمود شمال -> مباراة النهائي (يدخل من فوق - أفاتار النهائي العلوي)
    if (leftRounds.isNotEmpty) {
      final lastIdx = leftRounds.length - 1;
      final last = leftRounds[lastIdx];
      final colX = startX + lastIdx * (columnWidth + horizontalGap);
      final finalTopAvatarY = finalTopY + _avatarRadius;

      for (int i = 0; i < last.length; i++) {
        final mergeX = _drawAvatarMerge(canvas, paint, colX, i, last.length, toRight: true);
        final y = _centerY(i, last.length);
        final midX = (mergeX + centerColX) / 2;
        canvas.drawLine(Offset(mergeX, y), Offset(midX, y), paint);
        canvas.drawLine(Offset(midX, y), Offset(midX, finalTopAvatarY), paint);
        canvas.drawLine(Offset(midX, finalTopAvatarY), Offset(centerColX, finalTopAvatarY), paint);
      }
    }

    // ================= الفرع الأيمن (يتجه شمال ناحية الكأس) =================
    final reversedRight = rightRounds.reversed.toList();
    final double rightStartX = centerColX + (columnWidth + horizontalGap);

    for (int r = 0; r < reversedRight.length - 1; r++) {
      // التغذية لازم تيجي من العمود الأكتر ماتشات (الأبعد) للأقل (الأقرب للكأس)
      final feeder = reversedRight[r + 1];
      final target = reversedRight[r];
      final feederColX = rightStartX + (r + 1) * (columnWidth + horizontalGap);
      final targetColX = rightStartX + r * (columnWidth + horizontalGap);
      final targetRightEdge = targetColX + columnWidth;

      for (int i = 0; i < target.length; i++) {
        final mergeA = _drawAvatarMerge(canvas, paint, feederColX, i * 2, feeder.length, toRight: false);
        final hasB = i * 2 + 1 < feeder.length;
        final mergeB = hasB
            ? _drawAvatarMerge(canvas, paint, feederColX, i * 2 + 1, feeder.length, toRight: false)
            : mergeA;

        final yA = _centerY(i * 2, feeder.length);
        final yB = hasB ? _centerY(i * 2 + 1, feeder.length) : yA;
        final yTarget = _centerY(i, target.length);
        final midX = (mergeA + targetRightEdge) / 2;

        canvas.drawLine(Offset(mergeA, yA), Offset(midX, yA), paint);
        if (hasB) {
          canvas.drawLine(Offset(mergeB, yB), Offset(midX, yB), paint);
          canvas.drawLine(Offset(midX, yA), Offset(midX, yB), paint);
        }
        canvas.drawLine(Offset(midX, yTarget), Offset(targetRightEdge, yTarget), paint);
      }
    }

    // وصلة أقرب عمود يمين -> مباراة النهائي (يدخل من تحت - أفاتار النهائي السفلي)
    if (reversedRight.isNotEmpty) {
      final nearest = reversedRight.first;
      final finalBottomAvatarY = finalTopY + matchHeight - _avatarRadius;
      final rightEdgeOfCenter = centerColX + columnWidth;

      for (int i = 0; i < nearest.length; i++) {
        final mergeX = _drawAvatarMerge(canvas, paint, rightStartX, i, nearest.length, toRight: false);
        final y = _centerY(i, nearest.length);
        final midX = (mergeX + rightEdgeOfCenter) / 2;
        canvas.drawLine(Offset(mergeX, y), Offset(midX, y), paint);
        canvas.drawLine(Offset(midX, y), Offset(midX, finalBottomAvatarY), paint);
        canvas.drawLine(Offset(midX, finalBottomAvatarY), Offset(rightEdgeOfCenter, finalBottomAvatarY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

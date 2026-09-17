import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../art_core/theme/app_colors.dart';
import '../../domain/entities/tournament_entity.dart';
import 'bracket_layout.dart';
import 'bracket_match_node.dart';
import 'bracket_round_header.dart';
import 'split_bracket_painter.dart';

class TournamentBracketView extends StatelessWidget {
  final List<TournamentMatchEntity> matches;
  final Function(TournamentMatchEntity match)? onMatchTap;

  const TournamentBracketView({
    super.key,
    required this.matches,
    this.onMatchTap,
  });

  // العرض والمسافة الأفقية زي ما هما (مطلوب متتلمسش)
  static const double columnWidth = 62;
  static const double horizontalGap = 22;
  // matchHeight كانت 78 وده كان أقل من المحتوى الفعلي (36 + 36 + كتلة VS ~14px)
  // فده كان سبب "BOTTOM OVERFLOWED BY 7.0 PIXELS". كبّرناها + كبّرنا المسافات
  // الرأسية بس عشان نستغل الفراغ تحت بالطول (الـ FittedBox بيحسب السكيل من
  // العرض بس، فأي زيادة هنا بتزود طول الشجرة الكلي من غير ما تأثر على العرض).
  static const double matchHeight = 104;
  static const double firstRoundGap = 26;
  static const double topOffset = 46;
  static const double sidePadding = 16;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const BracketEmptyState();

    final roundsMap = <int, List<TournamentMatchEntity>>{};
    for (final match in matches) {
      roundsMap.putIfAbsent(match.roundNumber, () => []).add(match);
    }
    final sortedRoundNumbers = roundsMap.keys.toList()..sort();
    final rounds = sortedRoundNumbers
        .map((rn) => roundsMap[rn]!..sort((a, b) => a.matchOrder.compareTo(b.matchOrder)))
        .where((r) => r.isNotEmpty)
        .toList();

    if (rounds.isEmpty) return const BracketEmptyState();

    List<List<TournamentMatchEntity>> earlyRounds;
    TournamentMatchEntity? finalMatch;
    if (rounds.length > 1 && rounds.last.length == 1) {
      finalMatch = rounds.last.first;
      earlyRounds = rounds.sublist(0, rounds.length - 1);
    } else {
      earlyRounds = rounds;
    }

    final leftRounds = <List<TournamentMatchEntity>>[];
    final rightRounds = <List<TournamentMatchEntity>>[];
    for (final roundMatches in earlyRounds) {
      if (roundMatches.length >= 2) {
        final half = roundMatches.length ~/ 2;
        leftRounds.add(roundMatches.sublist(0, half));
        rightRounds.add(roundMatches.sublist(half));
      } else {
        leftRounds.add(roundMatches);
      }
    }

    final leftLayout = BracketLayout(
      rounds: leftRounds,
      matchHeight: matchHeight,
      firstRoundGap: firstRoundGap,
    );
    final rightLayout = BracketLayout(
      rounds: rightRounds,
      matchHeight: matchHeight,
      firstRoundGap: firstRoundGap,
    );

    final double branchHeight = [
      leftLayout.contentHeight,
      rightLayout.contentHeight,
      matchHeight,
    ].reduce((a, b) => a > b ? a : b);

    final double finalCenterY = branchHeight / 2;
    final double centerColX = sidePadding + leftRounds.length * (columnWidth + horizontalGap);
    final int totalColumns = leftRounds.length + 1 + rightRounds.length;
    final double totalWidth =
        sidePadding * 2 + totalColumns * columnWidth + (totalColumns - 1) * horizontalGap;
    final double totalHeight = topOffset + branchHeight + 40;

    // حد أدنى للسكيل عشان لو عدد اللاعبين كبر جدًا (32/64...) وعدد الأعمدة زاد،
    // الصور والنصوص متوصلش لحجم مش مقروء. لو محتاجين نكبر عن عرض الشاشة، الحل
    // بيبقى سكرول أفقي إضافي بدل ما نصغّر أكتر من الحد ده.
    const double minReadableScale = 0.55;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 360;
        final double rawScale = availableWidth / totalWidth;
        final double scale = rawScale < minReadableScale ? minReadableScale : rawScale;
        final double scaledWidth = totalWidth * scale;
        final double scaledHeight = totalHeight * scale;

        final bracketContent = SizedBox(
          width: scaledWidth,
          height: scaledHeight,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: totalWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SplitBracketPainter(
                        leftLayout: leftLayout,
                        rightLayout: rightLayout,
                        columnWidth: columnWidth,
                        horizontalGap: horizontalGap,
                        matchHeight: matchHeight,
                        topOffset: topOffset,
                        centerColX: centerColX,
                        finalCenterY: finalCenterY,
                        lineColor: AppColors.neonBlue.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  ..._buildLeftBranch(leftRounds, leftLayout),
                  ..._buildRightBranch(rightRounds, rightLayout, centerColX),
                  if (finalMatch != null) ..._buildFinal(finalMatch, centerColX, finalCenterY),
                ],
              ),
            ),
          ),
        );

        // مفيش أي إمكانية تكبير/تصغير باليد (زوم) في الحالتين تحت، فرق بينهم
        // بس هل محتاجين نسحب أفقي كمان ولا لأ:
        if (scale > rawScale) {
          // اتعمل clamp لفوق (يعني كان هيبقى أصغر من المسموح) فبقى أعرض من
          // الشاشة، فمحتاجين سكرول أفقي بالإضافة للرأسي.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: bracketContent,
            ),
          );
        }

        // الحالة العادية: بيملأ عرض الشاشة بالظبط وبيتسحب رأسي بس لو الطول زاد
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: bracketContent,
        );
      },
    );
  }

  List<Widget> _buildLeftBranch(
      List<List<TournamentMatchEntity>> leftRounds,
      BracketLayout layout,
      ) {
    final widgets = <Widget>[];
    for (int r = 0; r < leftRounds.length; r++) {
      final colX = sidePadding + r * (columnWidth + horizontalGap);
      widgets.add(Positioned(
        left: colX,
        top: 0,
        width: columnWidth,
        height: 32,
        child: BracketRoundHeader(
          roundsFromFinal: leftRounds.length - r,
          matchCountInRound: leftRounds[r].length * 2,
        ),
      ));
      final centers = layout.centersY[r];
      for (int i = 0; i < leftRounds[r].length; i++) {
        widgets.add(Positioned(
          left: colX,
          top: topOffset + centers[i] - matchHeight / 2,
          width: columnWidth,
          height: matchHeight,
          child: BracketMatchNode(
            match: leftRounds[r][i],
            onTap: () => onMatchTap?.call(leftRounds[r][i]),
          ),
        ));
      }
    }
    return widgets;
  }

  /// كانت دي فاضية (بگ) وده سبب اختفاء عمود ولاعبين الناحية اليمين بالكامل.
  /// دلوقتي بتبني كل أدوار الفرع الأيمن فعليًا، بنفس منطق الفرع الأيسر
  /// لكن بترتيب أعمدة معكوس (الأبعد عن الكأس على اليمين، الأقرب junto للنص).
  List<Widget> _buildRightBranch(
      List<List<TournamentMatchEntity>> rightRounds,
      BracketLayout layout,
      double centerColX,
      ) {
    final widgets = <Widget>[];
    final int n = rightRounds.length;
    if (n == 0) return widgets;

    final double rightStartX = centerColX + columnWidth + horizontalGap;

    for (int k = 0; k < n; k++) {
      // k=0 هو أقرب دور للكأس (نص نهائي)، وبيتحط في أول عمود بعد النص
      // وكل ما زاد k بنبعد لليمين لحد أول دور (اللي فيه أكتر عدد مباريات)
      final colX = rightStartX + (n - 1 - k) * (columnWidth + horizontalGap);

      widgets.add(Positioned(
        left: colX,
        top: 0,
        width: columnWidth,
        height: 32,
        child: BracketRoundHeader(
          roundsFromFinal: k + 1,
          matchCountInRound: rightRounds[k].length * 2,
        ),
      ));

      final centers = layout.centersY[k];
      for (int i = 0; i < rightRounds[k].length; i++) {
        widgets.add(Positioned(
          left: colX,
          top: topOffset + centers[i] - matchHeight / 2,
          width: columnWidth,
          height: matchHeight,
          child: BracketMatchNode(
            match: rightRounds[k][i],
            onTap: () => onMatchTap?.call(rightRounds[k][i]),
          ),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildFinal(
      TournamentMatchEntity finalMatch,
      double centerColX,
      double finalCenterY,
      ) {
    return [
      Positioned(
        left: centerColX,
        top: 0,
        width: columnWidth,
        child: _finalHeader(),
      ),
      Positioned(
        left: centerColX,
        top: topOffset + finalCenterY - matchHeight / 2,
        width: columnWidth,
        height: matchHeight,
        child: BracketMatchNode(
          match: finalMatch,
          onTap: () => onMatchTap?.call(finalMatch),
        ),
      ),
    ];
  }

  Widget _finalHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [
              AppColors.neonBlue.withValues(alpha: 0.25),
              AppColors.neonPurple.withValues(alpha: 0.25),
            ]),
            border: Border.all(color: AppColors.neonBlue, width: 1.5),
          ),
          child: const Icon(TablerIcons.trophy, color: AppColors.warning, size: 22),
        ),
        const SizedBox(height: 3),
        Text(
          'tournamentFinal'.tr(),
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
      ],
    );
  }
}
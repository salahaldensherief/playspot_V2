import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../art_core/theme/app_colors.dart';
import '../../domain/entities/tournament_entity.dart';
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

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const BracketEmptyState();
    }

    final roundsMap = <int, List<TournamentMatchEntity>>{};
    for (final match in matches) {
      roundsMap.putIfAbsent(match.roundNumber, () => []).add(match);
    }

    final sortedRoundNumbers = roundsMap.keys.toList()..sort();
    final rounds = sortedRoundNumbers
        .map(
          (roundNumber) => roundsMap[roundNumber]!
            ..sort((a, b) => a.matchOrder.compareTo(b.matchOrder)),
        )
        .where((round) => round.isNotEmpty)
        .toList();

    if (rounds.isEmpty) {
      return const BracketEmptyState();
    }

    List<List<TournamentMatchEntity>> bracketRounds;
    TournamentMatchEntity? finalMatch;

    if (rounds.length > 1 && rounds.last.length == 1) {
      finalMatch = rounds.last.first;
      bracketRounds = rounds.sublist(0, rounds.length - 1);
    } else {
      bracketRounds = rounds;
    }

    final leftRounds = <List<TournamentMatchEntity>>[];
    final rightRounds = <List<TournamentMatchEntity>>[];

    for (final roundMatches in bracketRounds) {
      if (roundMatches.length >= 2) {
        final half = roundMatches.length ~/ 2;
        leftRounds.add(roundMatches.sublist(0, half));
        rightRounds.add(roundMatches.sublist(half));
      } else {
        leftRounds.add(roundMatches);
      }
    }

    const double columnWidth = 110;
    const double horizontalGap = 16;
    const double matchHeight = 90;
    const double verticalGap = 16;
    const double topOffset = 40;

    final firstRoundMatchCount = [
      if (leftRounds.isNotEmpty) leftRounds.first.length,
      if (rightRounds.isNotEmpty) rightRounds.first.length,
      if (finalMatch != null) 1,
    ].fold<int>(0, (prev, val) => val > prev ? val : prev);

    final safeCount = firstRoundMatchCount <= 0 ? 1 : firstRoundMatchCount;
    final double branchHeight = safeCount * (matchHeight + verticalGap);

    final totalColumns = leftRounds.length + 1 + rightRounds.length;
    final double totalWidth = totalColumns * columnWidth + (totalColumns - 1) * horizontalGap;

    if (leftRounds.isEmpty && rightRounds.isEmpty && finalMatch != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(40),
            minScale: 0.3,
            maxScale: 2.5,
            constrained: true,
            child: Center(
              child: SizedBox(
                width: columnWidth + 40,
                height: matchHeight + 80,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 20,
                      width: columnWidth,
                      height: 32,
                      child: _buildFinalHeader(),
                    ),
                    Positioned(
                      left: 20,
                      top: 55,
                      width: columnWidth,
                      height: matchHeight,
                      child: BracketMatchNode(
                        match: finalMatch!,
                        onTap: () => onMatchTap?.call(finalMatch!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 400;
        final double availableHeight = constraints.maxHeight > 0 ? constraints.maxHeight : 500;
        final double scaleX = availableWidth / (totalWidth + 40);
        final double scaleY = availableHeight / (branchHeight + 100);
        final double scale = [scaleX, scaleY, 1.0].reduce((a, b) => a < b ? a : b).clamp(0.15, 1.2);

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(30),
          minScale: 0.1,
          maxScale: 3.0,
          constrained: true,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: totalWidth + 40,
                height: branchHeight + 80,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SplitBracketPainter(
                          leftRounds: leftRounds,
                          rightRounds: rightRounds,
                          columnWidth: columnWidth,
                          horizontalGap: horizontalGap,
                          matchHeight: matchHeight,
                          verticalGap: verticalGap,
                          branchHeight: branchHeight,
                          lineColor: AppColors.neonBlue.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    _buildBracketLayoutContent(
                      context,
                      leftRounds,
                      rightRounds,
                      finalMatch,
                      columnWidth,
                      horizontalGap,
                      matchHeight,
                      branchHeight,
                      topOffset,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinalHeader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.neonBlue.withValues(alpha: 0.25),
                AppColors.neonPurple.withValues(alpha: 0.25),
              ],
            ),
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

  Widget _buildBracketLayoutContent(
    BuildContext context,
    List<List<TournamentMatchEntity>> leftRounds,
    List<List<TournamentMatchEntity>> rightRounds,
    TournamentMatchEntity? finalMatch,
    double columnWidth,
    double horizontalGap,
    double matchHeight,
    double branchHeight,
    double topOffset,
  ) {
    final widgets = <Widget>[];
    double currentX = 20;

    // 1. Left Branch
    for (int r = 0; r < leftRounds.length; r++) {
      final matches = leftRounds[r];
      final colX = currentX;

      widgets.add(
        Positioned(
          left: colX,
          top: 0,
          width: columnWidth,
          height: 32,
          child: BracketRoundHeader(
            roundsFromFinal: leftRounds.length - r,
            matchCountInRound: matches.length,
          ),
        ),
      );

      final positions = _calculateRoundCenters(
        count: matches.length,
        branchHeight: branchHeight,
        matchHeight: matchHeight,
        topOffset: topOffset,
      );

      for (int i = 0; i < matches.length; i++) {
        widgets.add(
          Positioned(
            left: colX,
            top: positions[i] - (matchHeight / 2),
            width: columnWidth,
            height: matchHeight,
            child: BracketMatchNode(
              match: matches[i],
              onTap: () => onMatchTap?.call(matches[i]),
            ),
          ),
        );
      }
      currentX += columnWidth + horizontalGap;
    }

    // 2. Center (Trophy & Final Match)
    final double centerColX = currentX;

    if (finalMatch != null) {
      widgets.add(
        Positioned(
          left: centerColX,
          top: 0,
          width: columnWidth,
          child: _buildFinalHeader(),
        ),
      );

      final finalTopY = topOffset + branchHeight / 2 - (matchHeight / 2);

      widgets.add(
        Positioned(
          left: centerColX,
          top: finalTopY,
          width: columnWidth,
          height: matchHeight,
          child: BracketMatchNode(
            match: finalMatch,
            onTap: () => onMatchTap?.call(finalMatch),
          ),
        ),
      );
    }

    currentX += columnWidth + horizontalGap;

    // 3. Right Branch
    final rightRoundsOutToIn = rightRounds.reversed.toList();

    for (int r = 0; r < rightRoundsOutToIn.length; r++) {
      final matches = rightRoundsOutToIn[r];
      final colX = currentX;

      widgets.add(
        Positioned(
          left: colX,
          top: 0,
          width: columnWidth,
          height: 32,
          child: BracketRoundHeader(
            roundsFromFinal: r + 1,
            matchCountInRound: matches.length,
          ),
        ),
      );

      final positions = _calculateRoundCenters(
        count: matches.length,
        branchHeight: branchHeight,
        matchHeight: matchHeight,
        topOffset: topOffset,
      );

      for (int i = 0; i < matches.length; i++) {
        widgets.add(
          Positioned(
            left: colX,
            top: positions[i] - (matchHeight / 2),
            width: columnWidth,
            height: matchHeight,
            child: BracketMatchNode(
              match: matches[i],
              onTap: () => onMatchTap?.call(matches[i]),
            ),
          ),
        );
      }
      currentX += columnWidth + horizontalGap;
    }

    return Stack(children: widgets);
  }

  List<double> _calculateRoundCenters({
    required int count,
    required double branchHeight,
    required double matchHeight,
    required double topOffset,
  }) {
    if (count <= 0) return const [];
    if (count == 1) return [topOffset + branchHeight / 2];

    final available = branchHeight - matchHeight;
    final spacing = available / (count - 1);

    return List<double>.generate(
      count,
      (index) => topOffset + matchHeight / 2 + spacing * index,
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../domain/entities/tournament_entity.dart';

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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                TablerIcons.sitemap_off,
                size: 56,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'tournamentBracket'.tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group matches by round
    final Map<int, List<TournamentMatchEntity>> roundsMap = {};
    for (final match in matches) {
      roundsMap.putIfAbsent(match.roundNumber, () => []).add(match);
    }

    final sortedRounds = roundsMap.keys.toList()..sort();

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(120),
      minScale: 0.4,
      maxScale: 2.5,
      constrained: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedRounds.map((roundNumber) {
            final roundMatches = roundsMap[roundNumber]!
              ..sort((a, b) => a.matchOrder.compareTo(b.matchOrder));

            return Container(
              margin: const EdgeInsets.only(right: 48),
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Round Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.mutedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
                    ),
                    child: Text(
                      'round'.tr(args: ['$roundNumber']),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Matches Column
                  ...roundMatches.map((match) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _buildMatchNode(context, match),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMatchNode(BuildContext context, TournamentMatchEntity match) {
    final bool p1IsWinner = match.winnerId != null && match.winnerId == match.player1Id;
    final bool p2IsWinner = match.winnerId != null && match.winnerId == match.player2Id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.status == MatchStatus.inProgress
              ? AppColors.neonPurple
              : match.status == MatchStatus.completed
                  ? AppColors.neonBlue.withOpacity(0.5)
                  : AppColors.borderDefault,
          width: match.status == MatchStatus.inProgress ? 1.8 : 1.0,
        ),
        boxShadow: [
          if (match.status == MatchStatus.inProgress)
            BoxShadow(
              color: AppColors.neonPurple.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onMatchTap?.call(match),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station/Room Header
                if (match.stationNumber != null) ...[
                  Row(
                    children: [
                      const Icon(
                        TablerIcons.device_tv,
                        size: 12,
                        color: AppColors.neonBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${'roomStation'.tr()}: ${match.stationNumber}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.divider, height: 12),
                ],

                // Player 1 Row
                _buildPlayerRow(
                  name: match.player1Name ?? 'bye'.tr(),
                  score: match.player1Score,
                  isWinner: p1IsWinner,
                  isBye: match.player1Id == null,
                ),
                const SizedBox(height: 6),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 6),

                // Player 2 Row
                _buildPlayerRow(
                  name: match.player2Name ?? 'bye'.tr(),
                  score: match.player2Score,
                  isWinner: p2IsWinner,
                  isBye: match.player2Id == null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required String name,
    required int? score,
    required bool isWinner,
    required bool isBye,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isBye
                  ? AppColors.textSecondary.withOpacity(0.5)
                  : isWinner
                      ? AppColors.neonBlue
                      : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (score != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner ? AppColors.neonBlue.withOpacity(0.2) : AppColors.mutedBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                color: isWinner ? AppColors.neonBlue : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

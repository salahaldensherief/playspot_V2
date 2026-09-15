import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../domain/entities/tournament_entity.dart';
import 'tournament_status_badge.dart';

class TournamentCard extends StatelessWidget {
  final TournamentEntity tournament;
  final VoidCallback onTap;

  const TournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double capacityProgress = tournament.bracketSize > 0
        ? (tournament.registeredParticipantsCount / tournament.bracketSize).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.tournamentCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Banner Image Header
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: tournament.imageUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            memCacheHeight: 320,
                            placeholder: (context, url) => Container(
                              height: 160,
                              color: AppColors.tournamentHeaderBg,
                              child: const Center(
                                child: AppLoader(
                                  size: 28,
                                  strokeWidth: 2,
                                  color: AppColors.neonBlue,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _buildPlaceholderBanner(),
                          )
                        : _buildPlaceholderBanner(),
                  ),

                  // Dark Vignette & Cyber Gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.black.withValues(alpha: 0.35),
                            AppColors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Status Badge (Top Left)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: TournamentStatusBadge(
                      status: tournament.status,
                      compact: true,
                    ),
                  ),

                  // Entry Fee / Prize Badge (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.tournamentGold.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tournamentGold.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            TablerIcons.trophy,
                            size: 13,
                            color: AppColors.tournamentGold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tournament.entryFee > 0
                                ? '${tournament.entryFee.toStringAsFixed(0)} ${'egp'.tr()}'
                                : 'freeEntry'.tr(),
                            style: const TextStyle(
                              color: AppColors.tournamentGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Game Name Badge (Bottom Left)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.neonBlue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            TablerIcons.device_gamepad_2,
                            color: AppColors.neonBlue,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tournament.game,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    if (tournament.cityName != null || tournament.loungeName != null) ...[
                      Row(
                        children: [
                          Icon(
                            TablerIcons.map_pin,
                            color: AppColors.neonBlue.withValues(alpha: 0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${tournament.cityName ?? ''}${tournament.cityName != null && tournament.loungeName != null ? ' • ' : ''}${tournament.loungeName ?? ''}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Capacity Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              TablerIcons.users,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'participantsCapacity'.tr(args: [
                                '${tournament.registeredParticipantsCount}',
                                '${tournament.bracketSize}'
                              ]),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: capacityProgress >= 1.0
                                ? AppColors.warning.withValues(alpha: 0.2)
                                : AppColors.neonBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(capacityProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: capacityProgress >= 1.0 ? AppColors.warning : AppColors.neonBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Custom Gradient Capacity Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            color: AppColors.tournamentTrackBg,
                          ),
                          FractionallySizedBox(
                            widthFactor: capacityProgress,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: capacityProgress >= 1.0
                                      ? [AppColors.warning, AppColors.categoryFood]
                                      : [AppColors.neonBlue, AppColors.neonPurple],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.tournamentPlaceholderGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TablerIcons.trophy,
              size: 48,
              color: AppColors.neonBlue.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              tournament.game.toUpperCase(),
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

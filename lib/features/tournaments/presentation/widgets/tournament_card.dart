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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.neonBlue.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Header with Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: tournament.imageUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            memCacheHeight: 300,
                            placeholder: (context, url) => Container(
                              height: 150,
                              color: AppColors.mutedBackground,
                              child: const Center(
                                child: AppLoader(
                                  size: 24,
                                  strokeWidth: 2,
                                  color: AppColors.neonBlue,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),
                  ),
                  // Dark Overlay Gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Status Badge Top Left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: TournamentStatusBadge(
                      status: tournament.status,
                      compact: true,
                    ),
                  ),
                  // Entry Fee Badge Top Right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blackOverlay,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.neonPurple.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        tournament.entryFee > 0
                            ? '${tournament.entryFee.toStringAsFixed(0)} ${'egp'.tr()}'
                            : 'freeEntry'.tr(),
                        style: const TextStyle(
                          color: AppColors.neonPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Game Badge Bottom Left
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        const Icon(
                          TablerIcons.device_gamepad_2,
                          color: AppColors.neonBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tournament.game,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    if (tournament.cityName != null || tournament.loungeName != null) ...[
                      Row(
                        children: [
                          const Icon(
                            TablerIcons.map_pin,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${tournament.cityName ?? ''}${tournament.cityName != null && tournament.loungeName != null ? ' • ' : ''}${tournament.loungeName ?? ''}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Capacity Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        Text(
                          '${(capacityProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppColors.neonBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: capacityProgress,
                        minHeight: 6,
                        backgroundColor: AppColors.mutedBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          capacityProgress >= 1.0 ? AppColors.warning : AppColors.neonBlue,
                        ),
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

  Widget _buildPlaceholderImage() {
    return Container(
      height: 150,
      width: double.infinity,
      color: AppColors.mutedBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TablerIcons.trophy,
              size: 40,
              color: AppColors.neonBlue.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              tournament.game,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

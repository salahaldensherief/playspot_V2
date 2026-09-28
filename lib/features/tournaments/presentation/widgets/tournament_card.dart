import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
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

    final isFull = capacityProgress >= 1.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: GlassContainer(
        borderRadius: 20.r,
        blur: 14,
        borderOpacity: 0.15,
        borderColor: tournament.status == TournamentStatus.inProgress
            ? AppColors.neonPurple.withValues(alpha: 0.5)
            : AppColors.neonBlue.withValues(alpha: 0.3),
        color: AppColors.cardBackground.withValues(alpha: 0.55),
        child: Material(
          color: AppColors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Banner Image Header
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                      child: tournament.imageUrl?.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl: tournament.imageUrl!,
                              height: 165.h,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              memCacheHeight: 330,
                              placeholder: (context, url) => Container(
                                height: 165.h,
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

                    // Dark Cyber Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.black.withValues(alpha: 0.25),
                              AppColors.black.withValues(alpha: 0.90),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Status Badge (Top Start)
                    PositionedDirectional(
                      top: 12.h,
                      start: 12.w,
                      child: TournamentStatusBadge(
                        status: tournament.status,
                        compact: true,
                      ),
                    ),

                    // Entry Fee / Prize Badge (Top End)
                    PositionedDirectional(
                      top: 12.h,
                      end: 12.w,
                      child: GlassContainer(
                        borderRadius: 10.r,
                        blur: 8,
                        borderOpacity: 0.4,
                        borderColor: AppColors.tournamentGold.withValues(alpha: 0.7),
                        color: AppColors.black.withValues(alpha: 0.65),
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TablerIcons.trophy,
                              size: 13.sp,
                              color: AppColors.tournamentGold,
                            ),
                            SizedBox(width: 4.w),
                            AppText(
                              text: tournament.entryFee > 0
                                  ? '${tournament.entryFee.toStringAsFixed(0)} ${AppStrings.egp.tr()}'
                                  : AppStrings.freeEntry.tr(),
                              color: AppColors.tournamentGold,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Game Name Tag (Bottom Start)
                    PositionedDirectional(
                      bottom: 12.h,
                      start: 12.w,
                      child: GlassContainer(
                        borderRadius: 8.r,
                        blur: 8,
                        borderOpacity: 0.3,
                        borderColor: AppColors.neonBlue.withValues(alpha: 0.5),
                        color: AppColors.neonBlue.withValues(alpha: 0.15),
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TablerIcons.device_gamepad_2,
                              color: AppColors.neonBlue,
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 160.w),
                              child: AppText(
                                text: tournament.game,
                                color: AppColors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Card Body Content
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      AppText(
                        text: tournament.title,
                        color: AppColors.textPrimary,
                        fontSize: 16.5.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),

                      // Location & Lounge Row
                      if (tournament.cityName != null || tournament.loungeName != null) ...[
                        Row(
                          children: [
                            Icon(
                              TablerIcons.map_pin,
                              color: AppColors.neonBlue,
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: AppText(
                                text: '${tournament.cityName ?? ''}${tournament.cityName != null && tournament.loungeName != null ? ' • ' : ''}${tournament.loungeName ?? ''}',
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Capacity Progress Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                TablerIcons.users,
                                size: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 4.w),
                              AppText(
                                text: AppStrings.participantsCapacity.tr(
                                  args: [
                                    '${tournament.registeredParticipantsCount}',
                                    '${tournament.bracketSize}',
                                  ],
                                ),
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ],
                          ),
                          GlassContainer(
                            borderRadius: 6.r,
                            blur: 6,
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            borderColor: isFull
                                ? AppColors.warning.withValues(alpha: 0.4)
                                : AppColors.neonBlue.withValues(alpha: 0.3),
                            color: isFull
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : AppColors.neonBlue.withValues(alpha: 0.15),
                            child: AppText(
                              text: '${(capacityProgress * 100).toInt()}%',
                              color: isFull ? AppColors.warning : AppColors.neonBlue,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // Cyber Gradient Capacity Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: Stack(
                          children: [
                            Container(
                              height: 6.h,
                              color: AppColors.tournamentTrackBg,
                            ),
                            FractionallySizedBox(
                              widthFactor: capacityProgress,
                              child: Container(
                                height: 6.h,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isFull
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
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      height: 165.h,
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
              size: 48.sp,
              color: AppColors.neonBlue.withValues(alpha: 0.6),
            ),
            SizedBox(height: 8.h),
            AppText(
              text: tournament.game.toUpperCase(),
              color: AppColors.white.withValues(alpha: 0.8),
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ],
        ),
      ),
    );
  }
}

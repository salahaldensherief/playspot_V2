import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../domain/entities/tournament_entity.dart';
import 'tournament_info_tile.dart';

class TournamentParticipantsCard extends StatelessWidget {
  final TournamentEntity tournament;

  const TournamentParticipantsCard({
    super.key,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    final remainingSeats = (tournament.maxParticipants - tournament.registeredParticipantsCount).clamp(0, tournament.maxParticipants);
    final double fillPercentage = tournament.bracketSize > 0
        ? (tournament.registeredParticipantsCount / tournament.bracketSize).clamp(0.0, 1.0)
        : 0.0;

    return GlassContainer(
      padding: EdgeInsets.all(16.w),
      borderRadius: 16.r,
      blur: 12,
      borderColor: AppColors.neonBlue.withValues(alpha: 0.3),
      color: AppColors.cardBackground.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassContainer(
                padding: EdgeInsets.all(8.w),
                borderRadius: 10.r,
                blur: 6,
                borderColor: AppColors.neonBlue.withValues(alpha: 0.3),
                color: AppColors.neonBlue.withValues(alpha: 0.15),
                child: Icon(TablerIcons.users, color: AppColors.neonBlue, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppText(
                  text: AppStrings.maxParticipants.tr(),
                  color: AppColors.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GlassContainer(
                borderRadius: 8.r,
                blur: 6,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                borderColor: remainingSeats > 0 ? AppColors.successBorder : AppColors.dangerBorder,
                color: remainingSeats > 0
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.15),
                child: AppText(
                  text: '$remainingSeats ${AppStrings.remainingSeats.tr()}',
                  color: remainingSeats > 0 ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                text: AppStrings.maxParticipants.tr(),
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
              AppText(
                text: '${tournament.registeredParticipantsCount} / ${tournament.bracketSize}',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: fillPercentage,
              minHeight: 8.h,
              backgroundColor: AppColors.mutedBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
            ),
          ),
          if (tournament.registrationClosesAt != null || tournament.checkInOpensAt != null) ...[
            SizedBox(height: 16.h),
            const Divider(color: AppColors.divider, height: 1),
            SizedBox(height: 12.h),
          ],
          if (tournament.registrationClosesAt != null) ...[
            TournamentInfoTile(
              icon: TablerIcons.clock,
              label: AppStrings.registrationClosesAt.tr(),
              value: DateFormat('yyyy-MM-dd HH:mm').format(tournament.registrationClosesAt!),
            ),
            SizedBox(height: 10.h),
          ],
          if (tournament.checkInOpensAt != null) ...[
            TournamentInfoTile(
              icon: TablerIcons.clock_play,
              label: AppStrings.checkInWindow.tr(),
              value: '${DateFormat('HH:mm').format(tournament.checkInOpensAt!)} - ${tournament.checkInClosesAt != null ? DateFormat('HH:mm').format(tournament.checkInClosesAt!) : ''}',
            ),
          ],
        ],
      ),
    );
  }
}

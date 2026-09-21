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

class TournamentOverviewCard extends StatelessWidget {
  final TournamentEntity tournament;

  const TournamentOverviewCard({
    super.key,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    final entryFeeText = tournament.entryFee > 0
        ? '${tournament.entryFee.toStringAsFixed(0)} ${AppStrings.egp.tr()}'
        : AppStrings.freeEntry.tr();

    final isPaid = tournament.entryFee > 0;
    final feeColor = isPaid ? AppColors.warning : AppColors.success;

    return GlassContainer(
      padding: EdgeInsets.all(16.w),
      borderRadius: 16.r,
      blur: 12,
      borderColor: AppColors.neonPurple.withValues(alpha: 0.3),
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
                borderColor: AppColors.purple.withValues(alpha: 0.3),
                color: AppColors.purple.withValues(alpha: 0.15),
                child: Icon(TablerIcons.info_circle, color: AppColors.neonPurple, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              AppText(
                text: AppStrings.tournamentDetails.tr(),
                color: AppColors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TournamentInfoTile(
            icon: TablerIcons.device_gamepad,
            label: AppStrings.filterByGame.tr(),
            value: tournament.game,
          ),
          if (tournament.loungeName != null) ...[
            SizedBox(height: 10.h),
            TournamentInfoTile(
              icon: TablerIcons.building,
              label: AppStrings.loungeVenue.tr(),
              value: tournament.loungeName!,
            ),
          ],
          if (tournament.cityName != null) ...[
            SizedBox(height: 10.h),
            TournamentInfoTile(
              icon: TablerIcons.map_pin,
              label: AppStrings.city.tr(),
              value: tournament.cityName!,
            ),
          ],
          if (tournament.startDate != null) ...[
            SizedBox(height: 10.h),
            TournamentInfoTile(
              icon: TablerIcons.calendar_event,
              label: AppStrings.tournamentDate.tr(),
              value: DateFormat('yyyy-MM-dd HH:mm').format(tournament.startDate!),
            ),
          ],
          SizedBox(height: 10.h),
          TournamentInfoTile(
            icon: TablerIcons.ticket,
            label: AppStrings.entryFee.tr(),
            value: entryFeeText,
            iconColor: feeColor,
            customValueWidget: GlassContainer(
              borderRadius: 6.r,
              blur: 6,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              borderColor: feeColor.withValues(alpha: 0.4),
              color: feeColor.withValues(alpha: 0.15),
              child: AppText(
                text: entryFeeText,
                color: feeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

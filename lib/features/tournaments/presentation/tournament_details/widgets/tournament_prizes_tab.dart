import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../domain/entities/tournament_entity.dart';

class TournamentPrizesTab extends StatelessWidget {
  final List<TournamentPrizeEntity> prizes;

  const TournamentPrizesTab({
    super.key,
    required this.prizes,
  });

  @override
  Widget build(BuildContext context) {
    if (prizes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.trophy_off, size: 48.sp, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            SizedBox(height: 12.h),
            AppText(
              text: AppStrings.noResults.tr(),
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrizePoolHeader(prizes),
          SizedBox(height: 20.h),
          AppText(
            text: AppStrings.tournamentPrizes.tr(),
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 12.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prizes.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              return _buildPrizeCard(prizes[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrizePoolHeader(List<TournamentPrizeEntity> prizes) {
    final totalAmount = prizes.fold(0.0, (sum, p) => sum + p.amount);

    return GlassContainer(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      borderRadius: 16.r,
      blur: 14,
      borderColor: AppColors.warning.withValues(alpha: 0.6),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          GlassContainer(
            padding: EdgeInsets.all(12.w),
            borderRadius: 50.r,
            blur: 8,
            borderColor: AppColors.warning,
            color: AppColors.warning.withValues(alpha: 0.2),
            child: Icon(
              TablerIcons.trophy,
              color: AppColors.warning,
              size: 32.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: AppStrings.tournamentPrizes.tr(),
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: '${totalAmount.toStringAsFixed(0)} ${AppStrings.egp.tr()}',
                  color: AppColors.warning,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeCard(TournamentPrizeEntity prize) {
    final bool isFirst = prize.placement == 1;
    final bool isSecond = prize.placement == 2;
    final bool isThird = prize.placement == 3;

    final Color cardAccentColor = isFirst
        ? AppColors.warning
        : isSecond
            ? const Color(0xFFCBD5E1)
            : isThird
                ? const Color(0xFFCD7F32)
                : AppColors.neonBlue;

    final IconData rankIcon = isFirst
        ? TablerIcons.crown
        : isSecond
            ? TablerIcons.medal
            : isThird
                ? TablerIcons.award
                : TablerIcons.trophy;

    final String rankLabel = isFirst
        ? '1st'
        : isSecond
            ? '2nd'
            : isThird
                ? '3rd'
                : '#${prize.placement}';

    return GlassContainer(
      padding: EdgeInsets.all(16.w),
      borderRadius: 16.r,
      blur: 12,
      borderColor: cardAccentColor.withValues(alpha: isFirst ? 0.8 : 0.4),
      color: cardAccentColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          GlassContainer(
            padding: EdgeInsets.all(10.w),
            borderRadius: 12.r,
            blur: 6,
            borderColor: cardAccentColor.withValues(alpha: 0.5),
            color: cardAccentColor.withValues(alpha: 0.15),
            child: Icon(rankIcon, color: cardAccentColor, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: rankLabel,
                  color: cardAccentColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
                if (prize.description != null && prize.description!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  AppText(
                    text: prize.description!,
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ],
              ],
            ),
          ),
          AppText(
            text: '${prize.amount.toStringAsFixed(0)} ${AppStrings.egp.tr()}',
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}

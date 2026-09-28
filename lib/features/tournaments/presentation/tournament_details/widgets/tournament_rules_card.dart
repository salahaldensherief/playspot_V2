import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../domain/entities/tournament_entity.dart';

class TournamentRulesCard extends StatelessWidget {
  final TournamentEntity tournament;

  const TournamentRulesCard({
    super.key,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    final rulesText = tournament.rules != null && tournament.rules!.isNotEmpty
        ? tournament.rules!
        : (tournament.description ?? AppStrings.noRulesProvided.tr());

    final lines = rulesText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return GlassContainer(
      width: double.infinity,
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
                child: Icon(TablerIcons.gavel, color: AppColors.neonBlue, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              AppText(
                text: AppStrings.tournamentRules.tr(),
                color: AppColors.neonBlue,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (lines.length > 1)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lines.length,
              separatorBuilder: (context, index) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final lineText = lines[index].replaceFirst(RegExp(r'^\d+[.\-)]\s*'), '');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassContainer(
                      width: 24.w,
                      height: 24.w,
                      borderRadius: 12.r,
                      blur: 4,
                      borderColor: AppColors.neonBlue.withValues(alpha: 0.4),
                      color: AppColors.neonBlue.withValues(alpha: 0.15),
                      child: Center(
                        child: AppText(
                          text: '${index + 1}',
                          color: AppColors.neonBlue,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: AppText(
                          text: lineText,
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            GlassContainer(
              padding: EdgeInsets.all(12.w),
              borderRadius: 12.r,
              blur: 6,
              borderColor: AppColors.neonBlue.withValues(alpha: 0.3),
              color: AppColors.mutedBackground.withValues(alpha: 0.4),
              child: AppText(
                text: rulesText,
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';

import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/time/app_clock.dart';
import '../../../tournaments/domain/entities/tournament_entity.dart';

class TournamentPromoCard extends StatelessWidget {
  final TournamentEntity tournament;
  final bool isRegistered;
  final TournamentParticipantEntity? participant;
  final VoidCallback? onTap;

  const TournamentPromoCard({
    super.key,
    required this.tournament,
    this.isRegistered = false,
    this.participant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    final isArabic = context.locale.languageCode == 'ar';
    final title =
        (isArabic
                ? (tournament.titleAr ?? tournament.title)
                : (tournament.titleEn ?? tournament.title))
            .isNotEmpty
        ? (isArabic
              ? (tournament.titleAr ?? tournament.title)
              : (tournament.titleEn ?? tournament.title))
        : tournament.title;

    final targetDate =
        tournament.registrationClosesAt ??
        tournament.startDate ??
        DateTime.now().add(const Duration(days: 1));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: 2.horizontalPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.r24),
          gradient: AppColors.tournamentPromoGradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A9D00FF),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Tournament Image or Gradient Placeholder
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.r24),
                child:
                    tournament.imageUrl != null &&
                        tournament.imageUrl!.isNotEmpty
                    ? AppImage(
                        borderRadius: 0,
                        urlImg: tournament.imageUrl!,
                        fit: BoxFit.cover,
                        placeholderWidget: Container(
                          color: AppColors.tournamentHeaderBg,
                          child: const Center(
                            child: AppLoader(
                              size: 28,
                              strokeWidth: 2,
                              color: AppColors.neonBlue,
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.tournamentPromoGradient,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.tournamentPromoGradient,
                        ),
                      ),
              ),
            ),
            // Dark Vignette & Cyber Gradient Overlay for Text Readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.r24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0.35),
                      AppColors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            // Background Trophy Overlay
            Positioned(
              right: -15.w,
              bottom: -15.h,
              child: Icon(
                TablerIcons.trophy,
                size: 140.sp,
                color: AppColors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: 16.allPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppSizes.r8),
                          border: Border.all(
                            color: AppColors.neonBlue.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.swords,
                              size: 12.sp,
                              color: AppColors.neonBlue,
                            ),
                            4.horizontalSpace,
                            AppText(
                              text: AppStrings.tournaments.tr().toUpperCase(),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,

                              color: AppColors.neonBlue,
                            ),
                          ],
                        ),
                      ),
                      if (isRegistered && participant != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppSizes.r8),
                            border: Border.all(color: AppColors.neonPurple),
                          ),
                          child: AppText(
                            text: participant!.status
                                .toDbString()
                                .toUpperCase(),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,

                            color: AppColors.white,
                          ),
                        ),
                    ],
                  ),
                  8.verticalSpace,
                  AppText(
                    text: title,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,

                    color: AppColors.white,
                    height: 1.2,
                    maxLines: 1,
                  ),
                  6.verticalSpace,
                  Row(
                    children: [
                      if (isRegistered) ...[
                        Icon(
                          TablerIcons.clock,
                          size: 14.sp,
                          color: AppColors.neonBlue,
                        ),
                        4.horizontalSpace,
                        _TournamentCountdownTimer(targetDate: targetDate),
                        8.horizontalSpace,
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.device_gamepad_2,
                              size: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                            4.horizontalSpace,
                            Expanded(
                              child: AppText(
                                text: tournament.game,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCountdownTimer extends StatelessWidget {
  final DateTime targetDate;

  const _TournamentCountdownTimer({required this.targetDate});

  @override
  Widget build(BuildContext context) {
    return AppClockBuilder(
      builder: (context, now, child) {
        final difference = targetDate.difference(now);
        final timeLeft = difference.isNegative ? Duration.zero : difference;
        final hours = timeLeft.inHours;
        final minutes = timeLeft.inMinutes.remainder(60);
        final seconds = timeLeft.inSeconds.remainder(60);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: 0.3),
            ),
          ),
          child: AppText(
            text:
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,

            color: AppColors.neonBlue,
          ),
        );
      },
    );
  }
}

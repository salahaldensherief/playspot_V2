import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../tournaments/domain/entities/tournament_entity.dart';

class TournamentPromoCard extends StatefulWidget {
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
  State<TournamentPromoCard> createState() => _TournamentPromoCardState();
}

class _TournamentPromoCardState extends State<TournamentPromoCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.isRegistered) {
      _initTimer();
    }
  }

  @override
  void didUpdateWidget(covariant TournamentPromoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRegistered) {
      _initTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initTimer() {
    final targetDate = widget.tournament.registrationClosesAt ?? widget.tournament.startDate ?? DateTime.now().add(const Duration(days: 1));
    _updateTimeLeft(targetDate);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft(targetDate);
    });
  }

  void _updateTimeLeft(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    if (mounted) {
      setState(() {
        _timeLeft = difference.isNegative ? Duration.zero : difference;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    final isArabic = context.locale.languageCode == 'ar';
    final tournament = widget.tournament;
    final title = (isArabic ? (tournament.titleAr ?? tournament.title) : (tournament.titleEn ?? tournament.title)).isNotEmpty
        ? (isArabic ? (tournament.titleAr ?? tournament.title) : (tournament.titleEn ?? tournament.title))
        : tournament.title;

    final hours = _timeLeft.inHours;
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: 2.horizontalPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.r24),
          gradient: AppColors.tournamentPromoGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.neonPurple.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Tournament Image or Gradient Placeholder
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.r24),
                child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: tournament.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.tournamentHeaderBg,
                          child: const Center(
                            child: AppLoader(
                              size: 28,
                              strokeWidth: 2,
                              color: AppColors.neonBlue,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
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
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppSizes.r8),
                          border: Border.all(
                            color: AppColors.neonBlue.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(TablerIcons.swords, size: 12.sp, color: AppColors.neonBlue),
                            4.horizontalSpace,
                            AppText(
                              text: AppStrings.tournaments.tr().toUpperCase(),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                              color: AppColors.neonBlue,
                            ),
                          ],
                        ),
                      ),
                      if (widget.isRegistered && widget.participant != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppSizes.r8),
                            border: Border.all(color: AppColors.neonPurple),
                          ),
                          child: AppText(
                            text: widget.participant!.status.toDbString().toUpperCase(),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
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
                    fontFamily: 'Orbitron',
                    color: AppColors.white,
                    height: 1.2,
                    maxLines: 1,
                  ),
                  6.verticalSpace,
                  Row(
                    children: [
                      if (widget.isRegistered) ...[
                        Icon(TablerIcons.clock, size: 14.sp, color: AppColors.neonBlue),
                        4.horizontalSpace,
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                          ),
                          child: AppText(
                            text: '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                            color: AppColors.neonBlue,
                          ),
                        ),
                        8.horizontalSpace,
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            Icon(TablerIcons.device_gamepad_2, size: 14.sp, color: AppColors.textSecondary),
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

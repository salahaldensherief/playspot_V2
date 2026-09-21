import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/utils/extensions/date_time_extensions.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/directions_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../core/constants/booking_status.dart';
import '../../data/models/booking_model.dart';

class BookingCard extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  final bool isHighlighted;
  final bool isCancelling;

  const BookingCard({
    super.key,
    required this.booking,
    this.onCancel,
    this.isHighlighted = false,
    this.isCancelling = false,
  });

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  bool _showHighlight = false;
  Timer? _highlightTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _showHighlight = true;
      _startHighlightTimer();
    }
    _manageCountdownTimer();
  }

  @override
  void didUpdateWidget(covariant BookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      setState(() {
        _showHighlight = true;
      });
      _startHighlightTimer();
    }
    if (widget.booking != oldWidget.booking) {
      _manageCountdownTimer();
    }
  }

  void _startHighlightTimer() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHighlight = false;
        });
      }
    });
  }

  void _manageCountdownTimer() {
    _countdownTimer?.cancel();
    if (widget.booking.isUpcoming) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.booking.isUpcoming;

    final playModeText = widget.booking.playMode != null
        ? ' (${widget.booking.playMode == 'single' ? AppStrings.singlePlay.tr() : AppStrings.multiPlay.tr()})'
        : '';
    final spaceText =
        widget.booking.spaceType != null && widget.booking.spaceType!.isNotEmpty
        ? '${widget.booking.spaceType} - '
        : '';
    final roomSpecsText =
        "$spaceText${widget.booking.roomName}$playModeText · ${widget.booking.controllersCount} ${AppStrings.controllers.tr()} · ${widget.booking.screenSize}";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _showHighlight ? AppColors.neonBlue : AppColors.borderDefault,
          width: _showHighlight ? 1.5.w : .5.w,
        ),
        boxShadow: _showHighlight
            ? [
                BoxShadow(
                  color: AppColors.neonBlue.withValues(alpha: 0.35),
                  blurRadius: 5.r,
                  spreadRadius: 1.r,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AppText(
                  text: widget.booking.loungeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              SizedBox(width: 8.w),
              _buildBadgesRow(),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: AppColors.textSecondary,
                size: 16.sp,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: AppText(
                  text: widget.booking.loungeLocation,
                  fontSize: 12.sp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          AppText(
            text: roomSpecsText,
            fontSize: 12.sp,
            color: AppColors.textSecondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: AppColors.neonBlue,
                size: 16.sp,
              ),
              SizedBox(width: 8.w),
              AppText(
                text: widget.booking.date.toAppDateString(),
                fontSize: 14.sp,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.neonBlue, size: 16.sp),
              SizedBox(width: 8.w),
              AppText(
                text: widget.booking.startDateTime.toAppTimeString(),
                fontSize: 14.sp,
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          _buildCancellationReasonBanner(),
          if (isUpcoming) ...[
            SizedBox(height: 16.h),
            _buildCountdownBanner(),
            SizedBox(height: 12.h),
            _buildLatePolicyBanner(),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: DirectionsButton(
                    lat: widget.booking.lat,
                    lng: widget.booking.lng,
                    loungeName: widget.booking.loungeName,
                    loungeLocation: widget.booking.loungeLocation,
                    mapsLink: widget.booking.mapsLink,
                    height: 45.h,
                    isPrimary: true,
                  ),
                ),
                SizedBox(width: 12.w),
                AppButton(
                  content: ButtonContent(
                    label: widget.isCancelling ? null : AppStrings.cancel.tr(),
                    body: widget.isCancelling
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const AppLoader(strokeWidth: 2),
                          )
                        : null,
                  ),
                  behavior: ButtonBehavior.tap(
                    isEnabled: !widget.isCancelling,
                    onTap: widget.isCancelling ? null : widget.onCancel,
                  ),
                  buttonConfig: ButtonConfig(
                    height: 45.h,
                    width: 100.w,
                    borderRadius: 12.r,
                    backgroundColor: AppColors.transparent,
                    borderColor: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgesRow() {
    final isCash = widget.booking.paymentMethod?.toLowerCase() == 'cash';
    final paymentMethodText = isCash
        ? AppStrings.cashAtLounge.tr()
        : AppStrings.manualTransfer.tr();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.booking.isFirstBooking == true) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.neonPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
            ),
            child: AppText(
              text: AppStrings.firstBooking.tr(),
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.neonPurple,
            ),
          ),
          SizedBox(width: 6.w),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: AppText(
            text: paymentMethodText,
            fontSize: 10.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(width: 6.w),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildCancellationReasonBanner() {
    final reason = widget.booking.cancellationReason;
    if (reason == null || reason.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: AppStrings.cancellationReason.tr(),
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.danger,
          ),
          SizedBox(height: 4.h),
          AppText(
            text: reason,
            fontSize: 11.5.sp,
            color: Colors.white,
            height: 1.3,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isArabic = context.locale.languageCode == 'ar';
    Color color;
    String text;

    switch (widget.booking.status) {
      case BookingStatus.upcoming:
        color = AppColors.success;
        text = isArabic ? 'قادم' : 'Upcoming';
        break;
      case BookingStatus.pending:
        color = AppColors.warning;
        text = isArabic ? 'قيد المراجعة' : 'Pending';
        break;
      case BookingStatus.cancelled:
        color = AppColors.danger;
        text = isArabic ? 'ملغي' : 'Cancelled';
        break;
      default:
        color = AppColors.textSecondary;
        text = isArabic ? 'مكتمل' : 'Completed';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: AppText(
        text: text,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildCountdownBanner() {
    final now = DateTime.now();
    final diff = widget.booking.startDateTime.difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    final timeFormatted = diff.isNegative
        ? AppStrings.today.tr()
        : "${hours > 0 ? '${hours}h ' : ''}${mins}m";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            text: "${AppStrings.startsIn.tr()} ",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          AppText(
            text: timeFormatted,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.neonBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildLatePolicyBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.warning,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: AppText(
                  text: AppStrings.lateArrivalPolicyTitle.tr(),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          AppText(
            text: AppStrings.lateArrivalPolicyDesc.tr(),
            fontSize: 11.sp,
            color: AppColors.textSecondary,
            height: 1.3,
            overflow: TextOverflow.visible,
          ),
          if (widget.booking.status == BookingStatus.pending) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.neonBlue,
                    size: 14.sp,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: AppText(
                      text: AppStrings.bookingStatusPendingDesc.tr(),
                      fontSize: 11.sp,
                      color: AppColors.neonBlue,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

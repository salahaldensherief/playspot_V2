import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/directions_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/constants/booking_status.dart';
import '../../data/models/booking_model.dart';
import 'booking_qr_dialog.dart';

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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _showHighlight ? AppColors.neonBlue : AppColors.borderDefault,
          width: _showHighlight ? 1.5.w : 0.5.w,
        ),
        boxShadow: _showHighlight
            ? [
                BoxShadow(
                  color: AppColors.neonBlue.withValues(alpha: 0.35),
                  blurRadius: 8.r,
                  spreadRadius: 1.r,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Lounge Title Block (Full width, no truncation!)
          AppText(
            text: widget.booking.loungeName,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4.h),

          // Location Subtitle
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: AppColors.textSecondary,
                size: 14.sp,
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
          SizedBox(height: 10.h),

          // 2. Badges Row (Clean Wrap underneath title)
          _buildBadgesRow(),
          SizedBox(height: 12.h),

          // 3. Room & Specs Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.borderDefault.withValues(alpha: 0.5)),
            ),
            child: AppText(
              text: roomSpecsText,
              fontSize: 12.sp,
              color: AppColors.white.withValues(alpha: 0.9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 12.h),

          // 4. Date & Time Info Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: AppColors.neonBlue, size: 15.sp),
                SizedBox(width: 6.w),
                Flexible(
                  child: AppText(
                    text: widget.booking.date.toAppDateString(),
                    fontSize: 12.sp,
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 12.w),
                Icon(Icons.access_time_filled_rounded, color: AppColors.neonBlue, size: 15.sp),
                SizedBox(width: 6.w),
                AppText(
                  text: widget.booking.startDateTime.toAppTimeString(),
                  fontSize: 12.sp,
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),

          _buildCancellationReasonBanner(),

          if (isUpcoming) ...[
            SizedBox(height: 12.h),
            _buildCountdownBanner(),
            SizedBox(height: 10.h),
            _buildLatePolicyBanner(),
            SizedBox(height: 14.h),

            // Action Buttons Row (Upcoming)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DirectionsButton(
                    lat: widget.booking.lat,
                    lng: widget.booking.lng,
                    loungeName: widget.booking.loungeName,
                    loungeLocation: widget.booking.loungeLocation,
                    mapsLink: widget.booking.mapsLink,
                    height: 44.h,
                    isPrimary: true,
                  ),
                ),
                SizedBox(width: 8.w),
                InkWell(
                  onTap: () => BookingQrDialog.show(context, widget.booking),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.neonBlue,
                        size: 22.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 2,
                  child: AppButton(
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
                      height: 44.h,
                      borderRadius: 12.r,
                      backgroundColor: AppColors.transparent,
                      borderColor: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                if (widget.booking.mapsLink != null || widget.booking.lat != null) ...[
                  Expanded(
                    flex: 2,
                    child: DirectionsButton(
                      lat: widget.booking.lat,
                      lng: widget.booking.lng,
                      loungeName: widget.booking.loungeName,
                      loungeLocation: widget.booking.loungeLocation,
                      mapsLink: widget.booking.mapsLink,
                      height: 44.h,
                      isPrimary: false,
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                InkWell(
                  onTap: () => BookingQrDialog.show(context, widget.booking),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.textSecondary,
                        size: 22.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    content: ButtonContent(
                      label: AppStrings.rebook.tr(),
                      icon: Icon(Icons.refresh_rounded, size: 16.sp, color: Colors.white),
                    ),
                    behavior: ButtonBehavior.tap(
                      onTap: () {
                        if (widget.booking.loungeId != null && widget.booking.loungeId!.isNotEmpty) {
                          context.pushNamed(
                            RouterKeys.loungeDetails,
                            extra: {'loungeId': widget.booking.loungeId},
                          );
                        } else {
                          context.goNamed(RouterKeys.home);
                        }
                      },
                    ),
                    buttonConfig: ButtonConfig(
                      height: 44.h,
                      gradient: AppColors.primaryGradient,
                      borderRadius: 12.r,
                    ),
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

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildStatusBadge(),
        _buildPaymentStatusBadge(),
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
        ],
      ],
    );
  }

  Widget _buildPaymentStatusBadge() {
    final paymentStatus = widget.booking.paymentStatus.toLowerCase();
    Color color;
    String text;
    IconData? icon;

    switch (paymentStatus) {
      case 'paid':
        color = AppColors.success;
        text = AppStrings.paid.tr();
        icon = Icons.check_circle_outline;
        break;
      case 'partially_paid':
        color = AppColors.neonBlue;
        text = AppStrings.partiallyPaid.tr();
        icon = Icons.timelapse;
        break;
      case 'refunded':
        color = AppColors.neonPurple;
        text = AppStrings.refunded.tr();
        icon = Icons.replay;
        break;
      case 'pending':
        color = AppColors.warning;
        text = AppStrings.verificationPending.tr();
        icon = Icons.hourglass_top_rounded;
        break;
      case 'unpaid':
      default:
        color = AppColors.warning;
        text = AppStrings.unpaid.tr();
        icon = Icons.pending_outlined;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: color),
          SizedBox(width: 4.w),
          AppText(
            text: text,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationReasonBanner() {
    final reason = widget.booking.rejectionReason ?? widget.booking.cancellationReason;
    if (reason == null || reason.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final isRejection = widget.booking.rejectionReason != null && widget.booking.rejectionReason!.trim().isNotEmpty;

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
            text: isRejection ? AppStrings.rejectionReason.tr() : AppStrings.cancellationReason.tr(),
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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

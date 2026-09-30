import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/app_bottom_sheet.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/di.dart';
import '../../domain/usecases/join_slot_waitlist_usecase.dart';

class SlotWaitlistBottomSheet extends StatefulWidget {
  final String loungeId;
  final String loungeName;
  final List<String> roomIds;
  final DateTime date;
  final TimeOfDay slotTime;
  final VoidCallback? onSuccess;

  const SlotWaitlistBottomSheet({
    super.key,
    required this.loungeId,
    required this.loungeName,
    required this.roomIds,
    required this.date,
    required this.slotTime,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String loungeId,
    required String loungeName,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay slotTime,
    VoidCallback? onSuccess,
  }) {
    return AppBottomSheet.show(
      context: context,
      child: SlotWaitlistBottomSheet(
        loungeId: loungeId,
        loungeName: loungeName,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<SlotWaitlistBottomSheet> createState() =>
      _SlotWaitlistBottomSheetState();
}

class _SlotWaitlistBottomSheetState extends State<SlotWaitlistBottomSheet> {
  bool _isLoading = false;

  Future<void> _handleJoin() async {
    setState(() => _isLoading = true);

    final joinUseCase = sl<JoinSlotWaitlistUseCase>();
    final result = await joinUseCase(
      loungeId: widget.loungeId,
      roomIds: widget.roomIds,
      date: widget.date,
      slotTime: widget.slotTime,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        GameHudToast.show(
          context,
          AppStrings.notifyMeFailure.tr(),
          type: ToastType.error,
        );
      },
      (data) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();

        final msg = data.isPartial
            ? AppStrings.notifyMePartial.tr()
            : AppStrings.notifyMeSuccess.tr();

        GameHudToast.show(
          context,
          msg,
          type: ToastType.success,
        );
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.neonBlue,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: AppStrings.notifyMeForSlot.tr(),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    SizedBox(height: 2.h),
                    AppText(
                      text:
                          "${widget.loungeName} • ${_formatTime(widget.slotTime)}",
                      fontSize: 12.sp,
                      color: AppColors.neonBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: AppText(
              text: widget.roomIds.length > 1
                  ? AppStrings.notifyMePartial.tr()
                  : AppStrings.notifyMeSuccess.tr(),
              fontSize: 12.sp,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20.h),
          AppButton(
            content: ButtonContent(
              label: _isLoading ? null : AppStrings.notifyMe.tr(),
              icon: _isLoading
                  ? null
                  : Icon(
                      Icons.notifications_active_rounded,
                      size: 18.sp,
                      color: Colors.white,
                    ),
              body: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const AppLoader(strokeWidth: 2),
                    )
                  : null,
            ),
            behavior: ButtonBehavior.tap(
              isEnabled: !_isLoading,
              onTap: _isLoading ? null : _handleJoin,
            ),
            buttonConfig: ButtonConfig(
              height: 48.h,
              borderRadius: 12.r,
              gradient: AppColors.primaryGradient,
            ),
          ),
        ],
      ),
    );
  }
}

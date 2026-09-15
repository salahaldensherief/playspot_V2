import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import '../data/models/active_session_model.dart';
import 'active_session_cubit.dart';
import 'active_session_state.dart';
import 'widgets/active_session_body.dart';
import 'widgets/lounge_review_bottom_sheet.dart';

class ActiveSessionScreen extends StatefulWidget {
  final String? bookingId;
  final int? extensionMinutes;
  const ActiveSessionScreen({super.key, this.bookingId, this.extensionMinutes});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _hasShownExtensionDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActiveSessionCubit>().loadActiveSession(bookingId: widget.bookingId);
    });
  }

  void _showExtensionOfferDialog(BuildContext context, int minutes) {
    if (_hasShownExtensionDialog) return;
    _hasShownExtensionDialog = true;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: const BorderSide(color: AppColors.neonBlue, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.timer, color: AppColors.neonBlue),
            SizedBox(width: 10.w),
            Expanded(
              child: AppText(
                text: 'تمديد الحجز',
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: AppText(
          text: 'متبقي 5 دقائق على انتهاء حجزك. الساعة التالية متاحة، هل تريد تمديد الوقت بـ $minutes دقيقة؟',
          fontSize: 14.sp,
          color: AppColors.textSecondary,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  content: const ButtonContent(label: 'إلغاء'),
                  behavior: ButtonBehavior.tap(
                    onTap: () => Navigator.pop(dialogContext),
                  ),
                  buttonConfig: ButtonConfig(
                    height: 40.h,
                    backgroundColor: Colors.transparent,
                    borderColor: AppColors.textSecondary,
                    isOutlined: true,
                    borderRadius: 12.r,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppButton(
                  content: const ButtonContent(label: 'تأكيد التمديد'),
                  behavior: ButtonBehavior.tap(
                    onTap: () {
                      Navigator.pop(dialogContext);
                      final session = context.read<ActiveSessionCubit>().state.session;
                      if (session != null) {
                        double hourlyRate = 50.0;
                        final totalMinutes = session.endTime.difference(session.startTime).inMinutes;
                        if (totalMinutes > 0) {
                          hourlyRate = (session.basePrice / (totalMinutes / 60.0));
                        }
                        final cost = (hourlyRate * (minutes / 60.0)).roundToDouble();
                        context.read<ActiveSessionCubit>().extendTime(minutes, cost);
                      }
                    },
                  ),
                  buttonConfig: ButtonConfig(
                    height: 40.h,
                    backgroundColor: AppColors.neonBlue,
                    borderRadius: 12.r,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActiveSessionCubit, ActiveSessionState>(
      listenWhen: (prev, curr) =>
          prev.extendStatus != curr.extendStatus ||
          prev.orderStatus != curr.orderStatus ||
          prev.staffRequestStatus != curr.staffRequestStatus ||
          prev.session?.extensionStatus != curr.session?.extensionStatus ||
          prev.session?.endTime != curr.session?.endTime ||
          (prev.status != curr.status && (curr.status == ActiveSessionStatus.empty || curr.status == ActiveSessionStatus.loaded)),
      listener: (context, state) {
        if (state.status == ActiveSessionStatus.loaded && widget.extensionMinutes != null && !_hasShownExtensionDialog) {
          _showExtensionOfferDialog(context, widget.extensionMinutes!);
        }

        if (state.extendStatus == ActionStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.extensionSentMsg.tr(),
            type: ToastType.info,
          );
        }
        if (state.session != null) {
          final session = state.session!;
          if (session.extensionStatus == 'approved') {
            GameHudToast.show(
              context,
              AppStrings.extensionApprovedMsg.tr(),
              type: ToastType.success,
            );
          } else if (session.extensionStatus == 'rejected') {
            GameHudToast.show(
              context,
              AppStrings.extensionDeclinedMsg.tr(),
              type: ToastType.warning,
            );
          }
        }
        if (state.orderStatus == ActionStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.orderPlacedSuccess.tr(),
            type: ToastType.success,
          );
        }
        if (state.staffRequestStatus == ActionStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.staffNotifiedSuccess.tr(),
            type: ToastType.success,
          );
        }
        if (state.errorMessage != null &&
            (state.extendStatus == ActionStatus.error ||
                state.orderStatus == ActionStatus.error ||
                state.staffRequestStatus == ActionStatus.error)) {
          GameHudToast.show(
            context,
            state.errorMessage!,
            type: ToastType.error,
          );
        }

        if (state.status == ActiveSessionStatus.empty && state.session != null) {
          _showReviewBottomSheet(context, state.session!);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            text: AppStrings.activeSession.tr(),
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const ActiveSessionBody(),
      ),
    );
  }

  void _showReviewBottomSheet(BuildContext context, ActiveSessionModel session) {
    final cubit = context.read<ActiveSessionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoungeReviewBottomSheet(
        loungeName: session.loungeName,
        onSubmit: (rating, comment) => cubit.submitReview(rating: rating, comment: comment),
      ),
    ).then((_) {
      if (context.mounted) Navigator.pop(context);
    });
  }
}

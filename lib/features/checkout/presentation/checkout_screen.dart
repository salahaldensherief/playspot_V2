import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/utils/booking_error_formatter.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import 'checkout_cubit.dart';
import 'checkout_state.dart';
import 'widgets/booking_confirmed_dialog.dart';
import 'widgets/booking_rejected_dialog.dart';
import 'widgets/checkout_bottom_pay_bar.dart';
import 'widgets/checkout_countdown_timer_widget.dart';
import 'widgets/checkout_late_arrival_banner.dart';
import 'widgets/checkout_payment_methods_section.dart';
import 'widgets/checkout_summary_card.dart';
import 'widgets/checkout_voucher_section.dart';

class CheckoutScreen extends StatefulWidget {
  final CheckoutParams params;

  const CheckoutScreen({super.key, required this.params});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _voucherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CheckoutCubit>().initCheckout(widget.params.lounge);
      }
    });
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutCubit, CheckoutState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.liveBookingStatus != current.liveBookingStatus ||
          previous.isHoldExpired != current.isHoldExpired,
      listener: (context, state) {
        if (state.liveBookingStatus == BookingStatus.upcoming &&
            state.confirmedBooking != null) {
          BookingConfirmedDialog.show(context, state.confirmedBooking!);
          return;
        }

        if (state.liveBookingStatus == BookingStatus.cancelled &&
            state.rejectionReason != null) {
          BookingRejectedDialog.show(
            context: context,
            rejectionReason: state.rejectionReason!,
            onRetry: () {},
            onCancel: () => context.pop(),
          );
          return;
        }

        if (state.status == CheckoutStatus.success) {
          _showSuccessDialog(context);
        } else if (state.status == CheckoutStatus.failure) {
          final isEnglish = context.locale.languageCode == 'en';
          final errorMsg = getBookingErrorMessage(
            state.errorMessage ?? '',
            isEnglish,
          );
          GameHudToast.show(context, errorMsg, type: ToastType.error);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButtonWidget(),
          title: AppText(
            text: AppStrings.orderSummary.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CheckoutCountdownTimerWidget(),
              SizedBox(height: 16.h),
              CheckoutSummaryCard(params: widget.params),
              SizedBox(height: 20.h),
              CheckoutVoucherSection(
                voucherController: _voucherController,
                onVoucherChanged: () => setState(() {}),
              ),
              SizedBox(height: 24.h),
              AppText(
                text: AppStrings.paymentMethod.tr(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(height: 12.h),
              const CheckoutPaymentMethodsSection(),
              SizedBox(height: 14.h),
              CheckoutLateArrivalBanner(lounge: widget.params.lounge),
              SizedBox(height: 24.h),
              const _SecuredPaymentNote(),
              const SafeBottomSpacer(extraPadding: 140, androidOnly: false),
            ],
          ),
        ),
        bottomSheet: CheckoutBottomPayBar(params: widget.params),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    AppDialog.show(
      context,
      barrierDismissible: false,
      type: AppDialogType.success,
      title: AppStrings.bookingRequestedTitle,
      description:
          "${AppStrings.bookingPendingReview.tr()}\n\n${AppStrings.multiRoomAllowedNote.tr()}",
      confirmText: AppStrings.viewMyBookings,
      onConfirm: () => context.goNamed(RouterKeys.home),
    );
  }
}

class _SecuredPaymentNote extends StatelessWidget {
  const _SecuredPaymentNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, color: AppColors.neonBlue, size: 16.sp),
        SizedBox(width: 8.w),
        AppText(
          text: AppStrings.securedPayment.tr(),
          fontSize: 12.sp,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_state.dart';

import '../../../art_core/widgets/layout/glass_container.dart';
import '../../../art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../../core/utils/booking_error_formatter.dart';
import 'checkout_cubit.dart';
import 'checkout_state.dart';
import 'widgets/checkout_summary_card.dart';
import 'widgets/vodafone_cash_bottom_sheet.dart';

class CheckoutScreen extends StatefulWidget {
  final CheckoutParams params;

  const CheckoutScreen({
    super.key,
    required this.params,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _voucherController = TextEditingController();

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        return BlocListener<CheckoutCubit, CheckoutState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == CheckoutStatus.success) {
              _showSuccessDialog(context);
            } else if (state.status == CheckoutStatus.failure) {
              final isEnglish = context.locale.languageCode == 'en';
              final errorMsg = getBookingErrorMessage(
                state.errorMessage ?? '',
                isEnglish,
              );
              GameHudToast.show(
                context,
                errorMsg,
                type: ToastType.error,
              );
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
                  CheckoutSummaryCard(params: widget.params),
                  SizedBox(height: 16.h),
                  _buildLateArrivalPolicyBanner(),
                  SizedBox(height: 24.h),
                  _buildVoucherSection(),
                  SizedBox(height: 24.h),
                  AppText(
                    text: AppStrings.paymentMethod.tr(),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  SizedBox(height: 16.h),
                  _buildVodafoneCashInfoCard(),
                  SizedBox(height: 24.h),
                  _buildSecuredPaymentNote(),
                  const SafeBottomSpacer(extraPadding: 24),
                ],
              ),
            ),
            bottomSheet: _buildPayButton(),
          ),
        );
      },
    );
  }

  Widget _buildVoucherSection() {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) => previous.myVouchers != current.myVouchers,
      builder: (context, profileState) {
        final availableVouchers = profileState.myVouchers
            .where((v) => v['status'] == 'active')
            .toList();

        return BlocBuilder<CheckoutCubit, CheckoutState>(
          buildWhen: (previous, current) =>
              previous.selectedVoucher != current.selectedVoucher ||
              previous.discountAmount != current.discountAmount ||
              previous.status != current.status,
          builder: (context, checkoutState) {
            final isVoucherApplied = checkoutState.selectedVoucher != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      text: AppStrings.promoCode.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    if (isVoucherApplied)
                      AppButton(
                        content: ButtonContent(label: AppStrings.remove.tr()),
                        behavior: ButtonBehavior.tap(
                          onTap: () {
                            context.read<CheckoutCubit>().removeVoucher();
                            _voucherController.clear();
                          },
                        ),
                        buttonConfig: ButtonConfig(
                          height: 32.h,
                          backgroundColor: Colors.transparent,
                          borderRadius: 8.r,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (isVoucherApplied)
                  _buildAppliedVoucherCard(
                    checkoutState.selectedVoucher!,
                    checkoutState.discountAmount,
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _voucherController,
                          hint: AppStrings.referralCodeHint.tr(),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      AppButton(
                        content: ButtonContent(
                          label: AppStrings.redeem.tr(),
                        ),
                        buttonConfig: ButtonConfig(
                          gradient: _voucherController.text.trim().isNotEmpty
                              ? AppColors.primaryGradient
                              : null,
                          backgroundColor: AppColors.cardBackground,
                          borderColor: _voucherController.text.trim().isNotEmpty
                              ? AppColors.neonBlue
                              : AppColors.borderDefault,
                          borderRadius: 14.r,
                          width: 110.w,
                          height: 52.h,
                          textStyle: TextStyle(
                            color: _voucherController.text.trim().isNotEmpty
                                ? Colors.black
                                : AppColors.neonBlue,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        behavior: ButtonBehavior.tap(
                          isEnabled: _voucherController.text.trim().isNotEmpty &&
                              checkoutState.status != CheckoutStatus.loading,
                          onTap: () => context
                              .read<CheckoutCubit>()
                              .applyVoucher(_voucherController.text.trim()),
                        ),
                      ),
                    ],
                  ),
                  if (availableVouchers.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    _buildVoucherPicker(context, availableVouchers),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppliedVoucherCard(Map<String, dynamic> voucher, double discountAmount) {
    return GlassContainer(
      borderRadius: 15,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.confirmation_number_outlined, color: AppColors.success, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: voucher['code'],
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2.h),
                  AppText(
                    text: discountAmount > 0
                        ? AppStrings.youSaved.tr(args: [discountAmount.toStringAsFixed(0)])
                        : AppStrings.voucherApplied.tr(),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherPicker(BuildContext context, List<Map<String, dynamic>> vouchers) {
    return GestureDetector(
      onTap: () => _showVoucherPickerSheet(context, vouchers),
      child: GlassContainer(
        borderRadius: 15,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: AppColors.neonBlue),
              SizedBox(width: 12.w),
              AppText(
                text: AppStrings.selectVoucher.tr(),
                fontSize: 14.sp,
                color: Colors.white,
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoucherPickerSheet(BuildContext context, List<Map<String, dynamic>> vouchers) {
    final checkoutCubit = context.read<CheckoutCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.r))),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.availableVouchers.tr(),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 20.h),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vouchers.length,
                separatorBuilder: (_, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final voucher = vouchers[index];
                  return GestureDetector(
                    onTap: () {
                      checkoutCubit.selectVoucher(voucher);
                      Navigator.pop(sheetContext);
                    },
                    child: GlassContainer(
                      borderRadius: 15,
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  text: voucher['code'],
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neonBlue,
                                ),
                                AppText(
                                  text: _getRewardDescription(voucher),
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios, size: 14.sp, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  String _getRewardDescription(Map<String, dynamic> voucher) {
    if (voucher['reward_type'] == 'free_hour') {
      return AppStrings.freeHourReward.tr();
    }
    final val = voucher['reward_value']?.toString() ?? '0';
    return AppStrings.discountAmountReward.tr(args: [val]);
  }

  Widget _buildVodafoneCashInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(TablerIcons.wallet, color: AppColors.neonBlue, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: AppStrings.vodafoneCash.tr(),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: AppStrings.vodafoneCashHint.tr(),
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLateArrivalPolicyBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timer_outlined,
              color: AppColors.warning,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: AppStrings.lateArrivalPolicyTitle.tr(),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                AppText(
                  text: AppStrings.lateArrivalPolicyDesc.tr(),
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuredPaymentNote() {
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

  Widget _buildPayButton() {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) => 
        previous.status != current.status || 
        previous.discountAmount != current.discountAmount,
      builder: (context, state) {
        final finalPrice = widget.params.totalPrice - state.discountAmount;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          color: AppColors.scaffoldBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                content: ButtonContent(
                  label: state.status == CheckoutStatus.loading
                      ? AppStrings.processing.tr()
                      : AppStrings.payNowWithPrice.tr(args: [finalPrice.toStringAsFixed(2)]),
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: state.status != CheckoutStatus.loading,
                  onTap: () {
                    VodafoneCashBottomSheet.show(
                      context: context,
                      amount: finalPrice,
                      loungeName: widget.params.lounge.name,
                      walletNumber: widget.params.lounge.vodafoneCashNumber ?? '',
                      instaPayAccount: widget.params.lounge.instaPayAccount,
                      onConfirm: (method, receiptFile, senderPhone) {
                        context.read<CheckoutCubit>().processPayment(
                          widget.params,
                          isArabic: context.locale.languageCode == 'ar',
                          receiptFile: receiptFile,
                          paymentMethod: method,
                        );
                      },
                    );
                  },
                ),
                buttonConfig: ButtonConfig(
                  height: 55.h,
                  borderRadius: 15.r,
                  gradient: const LinearGradient(
                    colors: [AppColors.neonBlue, AppColors.neonPurple],
                  ),
                ),
              ),
              const SafeBottomSpacer(extraPadding: 40),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    AppDialog.show(
      context,
      barrierDismissible: false,
      type: AppDialogType.success,
      title: AppStrings.bookingRequestedTitle,
      description: "${AppStrings.bookingPendingReview.tr()}\n\n${AppStrings.multiRoomAllowedNote.tr()}",
      confirmText: AppStrings.viewMyBookings,
      onConfirm: () => context.goNamed(RouterKeys.home, extra: 1),
    );
  }
}

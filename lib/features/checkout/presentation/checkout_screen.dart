import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/art_core/widgets/layout/app_divider.dart';
import 'package:playspot/art_core/widgets/layout/info_row.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';
import 'package:playspot/core/utils/app_validators.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_state.dart';

import '../../../art_core/widgets/layout/glass_container.dart';
import '../../../art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../../core/cache/preference_manager.dart';
import 'checkout_cubit.dart';
import 'checkout_state.dart';

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
  final _formKey = GlobalKey<FormState>();
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
              GameHudToast.show(
                context,
                state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
                type: ToastType.error,
              );
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: AppText(
                text: AppStrings.orderSummary.tr(),
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            body: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(context),
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
                    _buildPaymentMethods(),
                    SizedBox(height: 24.h),
                    _buildCardDetailsSection(),
                    SizedBox(height: 32.h),
                    _buildSecuredPaymentNote(),
                    const SafeBottomSpacer(extraPadding: 120),
                  ],
                ),
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
          buildWhen: (previous, current) => previous.selectedVoucher != current.selectedVoucher || previous.status != current.status,
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
                      TextButton(
                        onPressed: () {
                          context.read<CheckoutCubit>().removeVoucher();
                          _voucherController.clear();
                        },
                        child: AppText(
                          text: AppStrings.remove.tr(),
                          color: AppColors.danger,
                          fontSize: 14.sp,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (isVoucherApplied)
                  _buildAppliedVoucherCard(checkoutState.selectedVoucher!)
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _voucherController,
                          hint: AppStrings.referralCodeHint.tr(),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      AppButton(
                        content: ButtonContent(label: AppStrings.redeem.tr()),
                        buttonConfig: ButtonConfig.gradient(
                          gradient: AppColors.primaryGradient,
                          width: 80.w,
                          height: 48.h,
                          borderRadius: 12.r,
                        ),
                        behavior: ButtonBehavior.tap(
                          isEnabled: _voucherController.text.isNotEmpty && checkoutState.status != CheckoutStatus.loading,
                          onTap: () => context.read<CheckoutCubit>().applyVoucher(_voucherController.text.trim()),
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

  Widget _buildAppliedVoucherCard(Map<String, dynamic> voucher) {
    return GlassContainer(
      borderRadius: 15,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(Icons.confirmation_number_outlined, color: AppColors.neonBlue),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: voucher['code'],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                AppText(
                  text: AppStrings.voucherApplied.tr(),
                  fontSize: 12.sp,
                  color: AppColors.success,
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.check_circle, color: AppColors.success),
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
    if (voucher['reward_type'] == 'free_hour') return "1 Free Hour";
    return "${voucher['reward_value']} EGP Discount";
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: widget.params.lounge.name,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
          SizedBox(height: 4.h),
          AppText(
            text:
                "${widget.params.room.spaceTypeLabel(context.locale.languageCode == 'ar')} - ${widget.params.room.getName(context.locale.languageCode == 'ar')} · ${widget.params.room.controllersCount} ${AppStrings.controllers.tr()} · ${widget.params.room.screenSize} ${AppStrings.screen.tr()}",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          if (widget.params.room.isSimulator || widget.params.room.isVR) ...[
            SizedBox(height: 4.h),
            AppText(
              text: widget.params.room.isSimulator ? "Setup: Fanatec Base + Triple 4K" : "Gear: Meta Quest 3 + Pro Straps",
              fontSize: 11.sp,
              color: AppColors.neonBlue,
              fontWeight: FontWeight.w500,
            ),
          ],
          SizedBox(height: 16.h),
          const AppDivider(),
          InfoRow(label: AppStrings.selectDate.tr(), value: widget.params.date.toAppDateString()),
          InfoRow(
              label: AppStrings.startTime.tr(), value: widget.params.startTime.toAppTimeString()),
          InfoRow(
              label: AppStrings.duration.tr(),
              value: widget.params.duration >= 60 
                  ? "${widget.params.duration / 60.0} ${AppStrings.hour_plural.tr(args: [''])}"
                  : "${widget.params.duration} ${"min30".tr()}"),
          if (widget.params.playMode != null)
            InfoRow(
              label: AppStrings.playMode.tr(),
              value: widget.params.playMode == 'single' 
                  ? AppStrings.singlePlay.tr() 
                  : AppStrings.multiPlay.tr(),
              valueColor: AppColors.neonBlue,
            ),
          if (widget.params.extraControllers != null && widget.params.extraControllers! > 0)
            InfoRow(
              label: context.locale.languageCode == 'ar' ? "دراعات إضافية" : "Extra Controllers",
              value: "${widget.params.extraControllers}x (+${(widget.params.extraControllers! * (widget.params.extraControllerPrice ?? 0)).toInt()} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()})",
              valueColor: AppColors.warning,
              prefixIcon: Icons.videogame_asset_outlined,
            ),
          if (widget.params.addOns.isNotEmpty) ...[
            SizedBox(height: 16.h),
            AppText(
              text: AppStrings.addOns.tr(),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8.h),
            ...widget.params.addOns.map((addOn) {
              IconData icon = Icons.local_drink_outlined;
              final name = addOn['name'].toString().toLowerCase();
              if (name.contains('snack') ||
                  name.contains('food') ||
                  name.contains('popcorn') ||
                  name.contains('pizza')) {
                icon = Icons.fastfood_outlined;
              }
              return InfoRow(
                label: "${addOn['quantity']}x ${addOn['name']}",
                value:
                    "${(addOn['price'] * addOn['quantity']).toInt()} ${AppStrings.egp.tr()}",
                labelColor: AppColors.white,
                fontSize: 14.sp,
                prefixIcon: icon,
              );
            }),
          ],
          const AppDivider(),
          SizedBox(height: 16.h),
          BlocBuilder<CheckoutCubit, CheckoutState>(
            buildWhen: (previous, current) => previous.discountAmount != current.discountAmount,
            builder: (context, state) {
              final roomPromoDiscount = widget.params.originalTotalPrice - widget.params.totalPrice;
              final totalDiscount = roomPromoDiscount + state.discountAmount;
              final finalPrice = widget.params.totalPrice - state.discountAmount;
              
              return Column(
                children: [
                  if (totalDiscount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          text: AppStrings.subtotal.tr(),
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                        AppText(
                          text: "${widget.params.originalTotalPrice.toInt()} ${AppStrings.egp.tr()}",
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          textDecoration: TextDecoration.lineThrough,
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          text: AppStrings.discount.tr(),
                          fontSize: 14.sp,
                          color: AppColors.success,
                        ),
                        AppText(
                          text: "-${totalDiscount.toInt()} ${AppStrings.egp.tr()}",
                          fontSize: 14.sp,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    if (roomPromoDiscount > 0 && state.discountAmount > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: AppText(
                          text: "(Incl. Room Offer & Voucher)",
                          fontSize: 10.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    SizedBox(height: 12.h),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        text: AppStrings.total.tr(),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                      AppText(
                        text: "${finalPrice.toInt()} ${AppStrings.egp.tr()}",
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonBlue,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) => previous.selectedMethod != current.selectedMethod,
      builder: (context, state) {
        return Column(
          children: [
            _buildPaymentOption(
              context,
              method: PaymentMethod.creditCard,
              icon: Icons.credit_card,
              label: AppStrings.creditCard.tr(),
              isSelected: state.selectedMethod == PaymentMethod.creditCard,
            ),
            SizedBox(height: 12.h),
            _buildPaymentOption(
              context,
              method: PaymentMethod.vodafoneCash,
              icon: Icons.phone_android,
              label: AppStrings.vodafoneCash.tr(),
              isSelected: state.selectedMethod == PaymentMethod.vodafoneCash,
            ),
            SizedBox(height: 12.h),
            _buildPaymentOption(
              context,
              method: PaymentMethod.fawry,
              icon: Icons.account_balance_wallet_outlined,
              label: AppStrings.fawry.tr(),
              isSelected: state.selectedMethod == PaymentMethod.fawry,
            ),
            SizedBox(height: 12.h),
            _buildPaymentOption(
              context,
              method: PaymentMethod.cash,
              icon: Icons.money,
              label: AppStrings.cash.tr(),
              isSelected: state.selectedMethod == PaymentMethod.cash,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentOption(
    BuildContext context, {
    required PaymentMethod method,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => context.read<CheckoutCubit>().selectPaymentMethod(method),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.neonBlue.withValues(alpha: 0.1)
                    : AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon,
                  color:
                      isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                  size: 20.sp),
            ),
            SizedBox(width: 16.w),
            AppText(
              text: label,
              fontSize: 16.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.neonBlue, size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetailsSection() {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) => previous.selectedMethod != current.selectedMethod,
      builder: (context, state) {
        if (state.selectedMethod != PaymentMethod.creditCard) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.cardDetails.tr(),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
            SizedBox(height: 16.h),
            AppTextField(
              label: AppStrings.cardNumber.tr(),
              hint: "1234 5678 9012 3456",
              textInputType: TextInputType.number,
              validator: (v) => AppValidators.validateNotEmpty(v, AppStrings.cardNumber.tr()),
            ),
            SizedBox(height: 16.h),
            AppTextField(
              label: AppStrings.cardholderName.tr(),
              hint: "Ahmed Mohamed",
              validator: (v) => AppValidators.validateNotEmpty(v, AppStrings.cardholderName.tr()),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: AppStrings.expiryDate.tr(),
                    hint: "MM/YY",
                    validator: (v) => AppValidators.validateNotEmpty(v, AppStrings.expiryDate.tr()),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AppTextField(
                    label: AppStrings.cvv.tr(),
                    hint: "123",
                    isPassword: true,
                    validator: (v) => AppValidators.validateNotEmpty(v, AppStrings.cvv.tr()),
                  ),
                ),
              ],
            ),
          ],
        );
      },
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
        previous.selectedMethod != current.selectedMethod ||
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
                      : state.selectedMethod == PaymentMethod.cash
                          ? AppStrings.confirmBookingWithPrice
                              .tr(args: [finalPrice.toInt().toString()])
                          : AppStrings.payNowWithPrice
                              .tr(args: [finalPrice.toInt().toString()]),
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: state.status != CheckoutStatus.loading,
                  onTap: () {
                    if (state.selectedMethod == PaymentMethod.creditCard) {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                    }
                    
                    final startDateTime = DateTime(
                      widget.params.date.year,
                      widget.params.date.month,
                      widget.params.date.day,
                      widget.params.startTime.hour,
                      widget.params.startTime.minute,
                    );
                    final endDateTime =
                        startDateTime.add(Duration(minutes: widget.params.duration));

                    final pref = sl<PreferenceManager>();
                    final userName = pref.fullName() ?? "";
                    final userPhone = pref.phoneNumber() ?? "";

                    final roomPromoDiscount = widget.params.originalTotalPrice - widget.params.totalPrice;
                    final totalDiscount = roomPromoDiscount + state.discountAmount;
                    final finalPrice = widget.params.totalPrice - state.discountAmount;

                    context.read<CheckoutCubit>().processPayment(
                      CreateBookingParams(
                        roomId: widget.params.room.id,
                        roomName: widget.params.room.getName(context.locale.languageCode == 'ar'),
                        loungeId: widget.params.lounge.id,
                        userName: userName,
                        userPhone: userPhone,
                        startTime: startDateTime,
                        endTime: endDateTime,
                        totalPrice: finalPrice,
                        discountAmount: totalDiscount,
                        roomPrice: widget.params.appliedHourlyRate ?? widget.params.room.effectivePrice,
                        addOns: widget.params.addOns,
                        playMode: widget.params.playMode,
                      ),
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
      description: AppStrings.bookingRequestedSubtitle,
      descriptionArgs: [widget.params.lounge.name],
      confirmText: AppStrings.viewMyBookings,
      onConfirm: () => context.goNamed(RouterKeys.home, extra: 1),
    );
  }
}

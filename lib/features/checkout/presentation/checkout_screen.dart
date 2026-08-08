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
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';

import '../../../art_core/widgets/layout/safe_bottom_spacer.dart';
import 'checkout_cubit.dart';
import 'checkout_state.dart';

class CheckoutScreen extends StatelessWidget {
  final LoungeModel lounge;
  final RoomModel room;
  final DateTime date;
  final TimeOfDay startTime;
  final int duration;
  final double totalPrice;
  final List<Map<String, dynamic>> addOns;

  const CheckoutScreen({
    super.key,
    required this.lounge,
    required this.room,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.totalPrice,
    required this.addOns,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<CheckoutCubit>(),
      child: BlocListener<CheckoutCubit, CheckoutState>(
        listener: (context, state) {
          if (state.status == CheckoutStatus.success) {
            _showSuccessDialog(context);
          } else if (state.status == CheckoutStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      state.errorMessage ?? AppStrings.somethingWentWrong.tr())),
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
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context),
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
          bottomSheet: _buildPayButton(),
        ),
      ),
    );
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
            text: lounge.name,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
          SizedBox(height: 4.h),
          AppText(
            text:
                "${room.getName(context.locale.languageCode == 'ar')} · ${room.controllersCount} ${AppStrings.controllers.tr()} · ${room.screenSize} ${AppStrings.screen.tr()} · ${room.capacity} Persons",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16.h),
          const AppDivider(),
          InfoRow(label: AppStrings.selectDate.tr(), value: date.toAppDateString()),
          InfoRow(
              label: AppStrings.startTime.tr(), value: startTime.toAppTimeString()),
          InfoRow(
              label: AppStrings.duration.tr(),
              value: AppStrings.hour.tr(args: [duration.toString()])),
          if (addOns.isNotEmpty) ...[
            SizedBox(height: 16.h),
            AppText(
              text: AppStrings.addOns.tr(),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8.h),
            ...addOns.map((addOn) {
              String icon = "🥤";
              final name = addOn['name'].toString().toLowerCase();
              if (name.contains('snack') ||
                  name.contains('food') ||
                  name.contains('popcorn') ||
                  name.contains('pizza')) {
                icon = "🍿";
              }
              return InfoRow(
                label: "$icon ${addOn['quantity']}x ${addOn['name']}",
                value:
                    "${(addOn['price'] * addOn['quantity']).toInt()} ${AppStrings.egp.tr()}",
                labelColor: AppColors.white,
                fontSize: 14.sp,
              );
            }),
          ],
          const AppDivider(),
          SizedBox(height: 16.h),
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
                text: "${totalPrice.toInt()} ${AppStrings.egp.tr()}",
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
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
            ),
            SizedBox(height: 16.h),
            AppTextField(
              label: AppStrings.cardholderName.tr(),
              hint: "Ahmed Mohamed",
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: AppStrings.expiryDate.tr(),
                    hint: "MM/YY",
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AppTextField(
                    label: AppStrings.cvv.tr(),
                    hint: "123",
                    isPassword: true,
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
      builder: (context, state) {
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
                              .tr(args: [totalPrice.toInt().toString()])
                          : AppStrings.payNowWithPrice
                              .tr(args: [totalPrice.toInt().toString()]),
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: state.status != CheckoutStatus.loading,
                  onTap: () {
                    final startDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      startTime.hour,
                      startTime.minute,
                    );
                    final endDateTime =
                        startDateTime.add(Duration(hours: duration));

                    context.read<CheckoutCubit>().processPayment(
                          roomId: room.id,
                          loungeId: lounge.id,
                          startTime: startDateTime,
                          endTime: endDateTime,
                          totalPrice: totalPrice,
                          roomPrice: room.pricePerHour,
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
      title: AppStrings.bookingConfirmedTitle,
      description: AppStrings.bookingConfirmedSubtitle,
      descriptionArgs: [lounge.name],
      confirmText: AppStrings.viewMyBookings,
      onConfirm: () => context.goNamed(RouterKeys.home, extra: 1),
    );
  }
}

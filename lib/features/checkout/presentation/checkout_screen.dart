import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
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
import 'package:playspot/features/lounge_details/data/room_model.dart';

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
              SnackBar(content: Text(state.errorMessage ?? "Something went wrong")),
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
            text: "Order Summary",
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
              _buildSummaryCard(),
              SizedBox(height: 24.h),
              AppText(
                text: "Payment Method",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(height: 16.h),
              _buildPaymentMethods(),
              SizedBox(height: 24.h),
              SizedBox(height: 32.h),
              _buildSecuredPaymentNote(),
              SizedBox(height: 100.h),
            ],
          ),
        ),
        bottomSheet: _buildPayButton(),
      ),
    ),
        );
  }

  Widget _buildSummaryCard() {
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
            text: "${room.name} · ${room.controllersCount} Controllers · ${room.screenSize} Screen",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16.h),
          const AppDivider(),
          InfoRow(label: "Date", value: _formatDate(date)),
          InfoRow(label: "Time", value: _formatTime(startTime)),
          InfoRow(label: "Duration", value: "$duration hour${duration > 1 ? 's' : ''}"),
          
          if (addOns.isNotEmpty) ...[
            SizedBox(height: 16.h),
            AppText(
              text: "Add-ons",
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8.h),
            ...addOns.map((addOn) {
              String icon = "🥤";
              final name = addOn['name'].toString().toLowerCase();
              if (name.contains('snack') || name.contains('food') || name.contains('popcorn') || name.contains('pizza')) {
                icon = "🍿";
              }
              return InfoRow(
                label: "$icon ${addOn['quantity']}x ${addOn['name']}",
                value: "${(addOn['price'] * addOn['quantity']).toInt()} EGP",
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
                text: "Total",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              AppText(
                text: "${totalPrice.toInt()} EGP",
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
              label: "Credit Card",
              isSelected: state.selectedMethod == PaymentMethod.creditCard,
            ),
            SizedBox(height: 12.h),
            _buildPaymentOption(
              context,
              method: PaymentMethod.vodafoneCash,
              icon: Icons.phone_android,
              label: "Vodafone Cash",
              isSelected: state.selectedMethod == PaymentMethod.vodafoneCash,
            ),
            SizedBox(height: 12.h),
            _buildPaymentOption(
              context,
              method: PaymentMethod.fawry,
              icon: Icons.account_balance_wallet_outlined,
              label: "Fawry",
              isSelected: state.selectedMethod == PaymentMethod.fawry,
            ),
            SizedBox(height: 12.h),
            _buildPaymentOption(
              context,
              method: PaymentMethod.cash,
              icon: Icons.money,
              label: "Cash",
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
                color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.1) : AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: isSelected ? AppColors.neonBlue : AppColors.textSecondary, size: 20.sp),
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
        if (state.selectedMethod != PaymentMethod.creditCard) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: "Card Details",
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
            SizedBox(height: 16.h),
            const AppTextField(
              label: "Card Number",
              hint: "1234 5678 9012 3456",
              textInputType: TextInputType.number,
            ),
            SizedBox(height: 16.h),
            const AppTextField(
              label: "Cardholder Name",
              hint: "Ahmed Mohamed",
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: const AppTextField(
                    label: "Expiry Date",
                    hint: "MM/YY",
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: const AppTextField(
                    label: "CVV",
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
          text: "Secured payment",
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
          padding: EdgeInsets.all(20.w),
          color: AppColors.scaffoldBackground,
          child: AppButton(
            content: ButtonContent(
              label: state.status == CheckoutStatus.loading 
                  ? "Processing..." 
                  : state.selectedMethod == PaymentMethod.cash
                      ? "Confirm Booking - ${totalPrice.toInt()} EGP"
                      : "Pay Now - ${totalPrice.toInt()} EGP",
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
                final endDateTime = startDateTime.add(Duration(hours: duration));

                context.read<CheckoutCubit>().processPayment(
                      roomId: room.id,
                      loungeId: lounge.id,
                      startTime: startDateTime,
                      endTime: endDateTime,
                      totalPrice: totalPrice,
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
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      return "Today, ${DateFormat('MMMM d').format(date)}";
    }
    return DateFormat('EEEE, MMMM d').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "$hour:00 $period";
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: AppColors.success, size: 60.sp),
              ),
              SizedBox(height: 24.h),
              AppText(
                text: "Booking Confirmed!",
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(height: 12.h),
              AppText(
                text: "Your spot at ${lounge.name} has been reserved. We're waiting for you!",
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              AppButton(
                content: const ButtonContent(label: "Great!"),
                behavior: ButtonBehavior.tap(
                  onTap: () {
                    Navigator.of(dialogContext).pop(); // Close dialog
                    Navigator.of(context).popUntil((route) => route.isFirst); // Go to Home
                  },
                ),
                buttonConfig: ButtonConfig(
                  height: 50.h,
                  borderRadius: 15.r,
                  gradient: const LinearGradient(
                    colors: [AppColors.neonBlue, AppColors.neonPurple],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

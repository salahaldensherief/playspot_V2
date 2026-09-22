import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/cards/order_summary_card.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import '../checkout_cubit.dart';
import '../checkout_state.dart';

class CheckoutSummaryCard extends StatelessWidget {
  final CheckoutParams params;

  const CheckoutSummaryCard({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) => previous.discountAmount != current.discountAmount,
      builder: (context, state) {
        final isArabic = context.locale.languageCode == 'ar';
        final roomOriginalSubtotal = params.originalRoomSubtotal;
        final roomDiscount = params.discountAmount;
        final voucherDiscount = state.discountAmount;
        final finalPrice = params.totalPrice - voucherDiscount;

        // Build session details rows
        final List<Map<String, dynamic>> sessionRows = [
          {'label': AppStrings.selectDate.tr(), 'value': params.date.toAppDateString()},
          {'label': AppStrings.startTime.tr(), 'value': params.startTime.toAppTimeString()},
          {
            'label': AppStrings.duration.tr(),
            'value': params.duration >= 60
                ? "${params.duration / 60.0} ${AppStrings.hour_plural.tr(args: [''])}"
                : "${params.duration} ${AppStrings.min30.tr()}"
          },
        ];

        if (params.rooms.length > 1) {
          sessionRows.add({
            'label': AppStrings.selectedRooms.tr(),
            'value': params.rooms.map((r) => r.getName(isArabic)).join(' + '),
            'color': AppColors.neonBlue,
          });
        }

        if (params.playMode != null) {
          sessionRows.add({
            'label': AppStrings.playMode.tr(),
            'value': params.playMode == 'single' ? AppStrings.singlePlay.tr() : AppStrings.multiPlay.tr(),
            'color': AppColors.neonBlue,
          });
        }

        if (params.extraControllers != null && params.extraControllers! > 0) {
          sessionRows.add({
            'label': AppStrings.extraControllers.tr(),
            'value': "${params.extraControllers}x (+${params.extraControllersChargePerHour.toStringAsFixed(2)} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()})",
            'color': AppColors.warning,
          });
        }

        // Build canteen / add-ons items
        final canteenItems = params.addOns.map((addOn) {
          IconData icon = Icons.local_drink_outlined;
          final name = addOn['name'].toString().toLowerCase();
          if (name.contains('snack') || name.contains('food') || name.contains('popcorn') || name.contains('pizza')) {
            icon = Icons.fastfood_outlined;
          }
          return OrderItemData(
            name: addOn['name'].toString(),
            quantity: (addOn['quantity'] as num).toInt(),
            price: (addOn['price'] as num).toDouble(),
            icon: icon,
          );
        }).toList();

        // Build discounts
        final List<DiscountData> discounts = [];
        if (roomDiscount > 0) {
          discounts.add(DiscountData(
            label: params.discountLabel ?? AppStrings.offerDiscount.tr(),
            amount: roomDiscount,
          ));
        }
        if (voucherDiscount > 0) {
          discounts.add(DiscountData(
            label: AppStrings.voucherDiscount.tr(),
            amount: voucherDiscount,
          ));
        }

        final roomSubtitle = params.rooms.length > 1
            ? "${AppStrings.bookRoomsCount.tr(args: [params.rooms.length.toString()])}: ${params.rooms.map((r) => r.getName(isArabic)).join(', ')}"
            : "${params.room.spaceTypeLabel(isArabic)} - ${params.room.getName(isArabic)} · ${params.room.controllersCount} ${AppStrings.controllers.tr()} · ${params.room.screenSize} ${AppStrings.screen.tr()}";

        return OrderSummaryCard(
          title: params.lounge.name,
          subtitle: roomSubtitle,
          statusText: isArabic ? "قيد التأكيد" : "Pending",
          statusColor: AppColors.warning,
          baseCostLabel: AppStrings.originalRoomPrice.tr(),
          baseCostAmount: roomOriginalSubtotal,
          sessionDetailsRows: sessionRows,
          canteenItems: canteenItems,
          discounts: discounts,
          grandTotal: finalPrice,
        );
      },
    );
  }
}

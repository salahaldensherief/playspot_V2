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
      buildWhen: (previous, current) =>
          previous.discountAmount != current.discountAmount ||
          previous.serverQuote != current.serverQuote,
      builder: (context, state) {
        final isArabic = context.locale.languageCode == 'ar';
        final quote = state.serverQuote;
        final roomOriginalSubtotal =
            (quote?['original_rooms_total'] as num?)?.toDouble() ??
            params.originalRoomSubtotal;
        final roomDiscount =
            (quote?['promo_discount_total'] as num?)?.toDouble() ??
            params.discountAmount;
        final voucherDiscount =
            (quote?['voucher_discount'] as num?)?.toDouble() ??
            state.discountAmount;
        final finalPrice =
            (quote?['final_total'] as num?)?.toDouble() ??
            params.calculateFinalPrice(voucherDiscount);

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
        final quoteExtras = quote?['extras'];
        final sourceExtras = quoteExtras is List ? quoteExtras : params.addOns;
        final canteenItems = sourceExtras.map((rawAddOn) {
          final addOn = Map<String, dynamic>.from(rawAddOn as Map);
          IconData icon = Icons.local_drink_outlined;
          final itemName = (addOn['name'] ?? '').toString();
          final normalizedName = itemName.toLowerCase();
          if (normalizedName.contains('snack') ||
              normalizedName.contains('food') ||
              normalizedName.contains('popcorn') ||
              normalizedName.contains('pizza')) {
            icon = Icons.fastfood_outlined;
          }

          return OrderItemData(
            name: itemName,
            quantity: (addOn['quantity'] as num?)?.toInt() ?? 1,
            price: (addOn['unit_price'] as num?)?.toDouble() ??
                (addOn['price'] as num?)?.toDouble() ??
                0,
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
          statusText: AppStrings.pendingConfirmation.tr(),
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

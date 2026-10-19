import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'canteen_menu_item.dart';

/// Returns true to keep selected extras, false to continue without them, and
/// null when the customer closes the prompt without starting a booking.
class BookingCanteenOfferDialog extends StatelessWidget {
  const BookingCanteenOfferDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final height = math.min(620.0, MediaQuery.sizeOf(context).height - 48);
    return Dialog(
      backgroundColor: AppColors.scaffoldBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 560,
        height: height,
        child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          buildWhen: (before, after) =>
              before.extras != after.extras ||
              before.selectedExtras != after.selectedExtras,
          builder: (context, state) {
            final available = state.extras
                .where((extra) => extra.isAvailable)
                .toList();
            final count = available.fold<int>(
              0,
              (sum, extra) => sum + (state.selectedExtras[extra.id] ?? 0),
            );
            final total = available.fold<double>(
              0,
              (sum, extra) =>
                  sum + extra.price * (state.selectedExtras[extra.id] ?? 0),
            );

            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.bookingCanteenOfferTitle.tr(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppStrings.close.tr(),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.bookingCanteenOfferSubtitle.tr(),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: available.isEmpty
                        ? Center(
                            child: Text(
                              AppStrings.canteenMenuEmpty.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: available.length,
                            itemBuilder: (context, index) =>
                                CanteenMenuItem(extra: available[index]),
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (count > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Text(
                        '${AppStrings.canteenSelectedCount.tr(namedArgs: {'count': '$count'})} · ${total.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    AppStrings.bookingCanteenOfferPriceNote.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: count > 0
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.buttonPrimaryText,
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(AppStrings.bookingCanteenOfferAdd.tr()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppStrings.bookingCanteenOfferNoThanks.tr()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

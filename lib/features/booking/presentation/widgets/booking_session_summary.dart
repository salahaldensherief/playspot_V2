import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import '../booking_cubit.dart';
import '../booking_state.dart';

class BookingSessionSummary extends StatelessWidget {
  final BookingDetailsParams params;

  const BookingSessionSummary({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.startTime != current.startTime ||
          previous.durationMinutes != current.durationMinutes ||
          previous.playMode != current.playMode ||
          previous.extraControllersCount != current.extraControllersCount,
      builder: (context, state) {
        final startTime = state.startTime;
        if (startTime == null) return const SizedBox.shrink();

        final isArabic = context.locale.languageCode == 'ar';
        final start = DateTime(2000, 1, 1, startTime.hour, startTime.minute);
        final end = start.add(Duration(minutes: state.durationMinutes));
        final endTime = TimeOfDay.fromDateTime(end);

        final offerInfo = state.getOfferInfo(params, isArabic);
        final subtotals = state.getCalculatedSubtotals(params, isArabic);
        final origRoomSubtotal = subtotals['originalRoomSubtotal'] ?? 0.0;
        final discRoomSubtotal = subtotals['discountedRoomSubtotal'] ?? 0.0;
        final roomDiscountAmount = subtotals['roomDiscountAmount'] ?? 0.0;

        return Container(
          padding: 16.allPadding,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r16),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                text: AppStrings.sessionDetails.tr(),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              16.verticalSpace,
              _buildSummaryRow(
                "Time Slot",
                "${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}",
              ),
              8.verticalSpace,
              _buildSummaryRow(
                AppStrings.playMode.tr(),
                state.playMode == PlayMode.single
                    ? AppStrings.singlePlay.tr()
                    : AppStrings.multiPlay.tr(),
              ),
              if (state.extraControllersCount > 0) ...[
                8.verticalSpace,
                _buildSummaryRow(
                  AppStrings.extraControllers.tr(),
                  "+${state.extraControllersCount}",
                ),
              ],
              8.verticalSpace,
              _buildSummaryRow(
                AppStrings.duration.tr(),
                "${state.durationMinutes} mins",
              ),
              const Divider(color: AppColors.borderDefault, height: 24),
              if (offerInfo.hasOffer) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      text:
                          offerInfo.discountLabel ??
                          AppStrings.activeOffer.tr(),
                      fontSize: 12.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                    AppText(
                      text:
                          "-${roomDiscountAmount.toInt()} ${AppStrings.egp.tr()}",
                      fontSize: 12.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
                8.verticalSpace,
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText(
                    text: AppStrings.totalAmount.tr(),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  Row(
                    children: [
                      if (offerInfo.hasOffer) ...[
                        Text(
                          "${origRoomSubtotal.toInt()} ${AppStrings.egp.tr()}",
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        8.horizontalSpace,
                      ],
                      PriceWidget(
                        price: discRoomSubtotal,
                        fontSize: 18.sp,
                        color: offerInfo.hasOffer
                            ? AppColors.success
                            : AppColors.neonBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(text: label, fontSize: 13.sp, color: AppColors.textSecondary),
        AppText(
          text: value,
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "$hour:$minute $period";
  }
}

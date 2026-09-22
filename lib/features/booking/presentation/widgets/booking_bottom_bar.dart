import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import '../booking_cubit.dart';
import '../booking_state.dart';

class BookingBottomBar extends StatefulWidget {
  final BookingDetailsParams params;

  const BookingBottomBar({
    super.key,
    required this.params,
  });

  @override
  State<BookingBottomBar> createState() => _BookingBottomBarState();
}

class _BookingBottomBarState extends State<BookingBottomBar> {
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.startTime != current.startTime ||
          previous.status != current.status ||
          previous.durationMinutes != current.durationMinutes ||
          previous.playMode != current.playMode ||
          previous.extraControllersCount != current.extraControllersCount,
      builder: (context, state) {
        final canProceed =
            state.startTime != null &&
            state.status != BookingStatus.loading &&
            !_isVerifying;

        final isArabic = context.locale.languageCode == 'ar';
        final subtotals = state.getCalculatedSubtotals(widget.params, isArabic);
        final offerInfo = state.getOfferInfo(widget.params, isArabic);
        final totalPrice = subtotals['discountedRoomSubtotal'] ?? 0.0;

        return Container(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 12.h,
            bottom: 12.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          text: AppStrings.totalPrice.tr(),
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                        PriceWidget(
                          price: totalPrice,
                          fontSize: 20.sp,
                          color: AppColors.neonBlue,
                        ),
                      ],
                    ),
                  ),
                  16.horizontalSpace,
                  Expanded(
                    child: AppButton(
                      behavior: ButtonBehavior.tap(
                        isEnabled: canProceed,
                        isLoading:
                            state.status == BookingStatus.loading ||
                            _isVerifying,
                        onTap: () async {
                          if (!canProceed) return;

                          setState(() => _isVerifying = true);

                          final cubit = context.read<BookingCubit>();
                          final isAvailable = await cubit
                              .verifyAvailabilityBeforeProceed();

                          if (!mounted) return;
                          setState(() => _isVerifying = false);

                          if (isAvailable && mounted) {
                            final currentState = cubit.state;
                            if (currentState.startTime == null) return;

                            final params = widget.params;
                            final room = params.room;
                            final lounge = params.lounge;

                            final startTime = currentState.startTime!;

                            final rawBreakdown = subtotals['roomsBreakdown'];
                            final List<Map<String, dynamic>> roomsBreakdown = (rawBreakdown is List)
                                ? rawBreakdown.whereType<Map<String, dynamic>>().toList()
                                : <Map<String, dynamic>>[];

                            final checkoutParams = CheckoutParams(
                              lounge: lounge,
                              rooms: params.rooms,
                              roomsBreakdown: roomsBreakdown,
                              date: currentState.selectedDate,
                              startTime: startTime,
                              duration: currentState.durationMinutes,
                              originalRoomSubtotal:
                                  subtotals['originalRoomSubtotal'] ?? 0.0,
                              discountedRoomSubtotal:
                                  subtotals['discountedRoomSubtotal'] ?? 0.0,
                              discountAmount:
                                  subtotals['roomDiscountAmount'] ?? 0.0,
                              discountPercentage: offerInfo.discountPercentage,
                              discountLabel: offerInfo.discountLabel,
                              discountSource: offerInfo.discountSource,
                              addonsTotal: subtotals['addonsTotal'] ?? 0.0,
                              totalPrice: totalPrice,
                              originalTotalPrice:
                                  subtotals['originalTotalPrice'] ?? totalPrice,
                              addOns: params.extras,
                              playMode: currentState.playMode == PlayMode.single
                                  ? 'single'
                                  : 'multi',
                              extraControllers:
                                  currentState.extraControllersCount,
                              extraControllerPrice: room.extraControllerPrice,
                              appliedHourlyRate: offerInfo.discountedHourlyRate,
                            );

                            if (context.mounted) {
                              context.pushNamed(
                                RouterKeys.checkout,
                                extra: checkoutParams,
                              );
                            }
                          }
                        },
                      ),
                      buttonConfig: ButtonConfig(
                        gradient: AppColors.primaryGradient,
                        borderRadius: 15.r,
                        height: 50.h,
                        backgroundColor: AppColors.neonBlue,
                      ),
                      content: ButtonContent(
                        body: AppText(
                          text: _isVerifying
                              ? "Checking..."
                              : AppStrings.continueText.tr(),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SafeBottomSpacer(),
            ],
          ),
        );
      },
    );
  }
}

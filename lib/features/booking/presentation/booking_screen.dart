import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import '../../../art_core/router/router_keys.dart';
import '../../../core/utils/booking_error_formatter.dart';
import 'booking_cubit.dart';
import 'booking_state.dart';
import 'widgets/duration_selector.dart';
import 'widgets/time_slot_grid.dart';

class BookingScreen extends StatefulWidget {
  final BookingDetailsParams params;

  const BookingScreen({super.key, required this.params});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDurationAndSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingCubit, BookingState>(
      listenWhen: (previous, current) =>
          (previous.status != current.status &&
              current.status == BookingStatus.error) ||
          (previous.startTime != current.startTime &&
              current.startTime != null),
      listener: (context, state) {
        if (state.status == BookingStatus.error && state.errorMessage != null) {
          final isEnglish = context.locale.languageCode == 'en';
          final errorMsg = getBookingErrorMessage(
            state.errorMessage!,
            isEnglish,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state.startTime != null) {
          _scrollToDurationAndSummary();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButtonWidget(),
          title: AppText(
            text:
                "${AppStrings.book.tr()} ${widget.params.room.getDisplayTitle(context.locale.languageCode == 'ar')}",
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: 16.allPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: AppStrings.selectTime.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    16.verticalSpace,
                    const TimeSlotGrid(),
                    24.verticalSpace,
                    AppText(
                      text: AppStrings.duration.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    16.verticalSpace,
                    const DurationSelector(),
                    32.verticalSpace,
                    _buildSummary(),
                    32.verticalSpace,
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
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

        final offerInfo = state.getOfferInfo(widget.params, isArabic);
        final subtotals = state.getCalculatedSubtotals(widget.params, isArabic);
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

  Widget _buildBottomBar(BuildContext context) {
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

                          if (isAvailable) {
                            final currentState = cubit.state;
                            if (currentState.startTime == null) return;

                            final params = widget.params;
                            final room = params.room;
                            final lounge = params.lounge;

                            final startTime = currentState.startTime!;

                            final checkoutParams = CheckoutParams(
                              lounge: lounge,
                              room: room,
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

                            context.pushNamed(
                              RouterKeys.checkout,
                              extra: checkoutParams,
                            );
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

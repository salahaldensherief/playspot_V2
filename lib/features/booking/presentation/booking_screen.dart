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

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingCubit, BookingState>(
      listenWhen: (previous, current) =>
          (previous.status != current.status &&
          current.status == BookingStatus.error),
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
          previous.durationMinutes != current.durationMinutes,
      builder: (context, state) {
        final startTime = state.startTime;
        if (startTime == null) return const SizedBox.shrink();

        final isArabic = context.locale.languageCode == 'ar';
        final start = DateTime(2000, 1, 1, startTime.hour, startTime.minute);
        final end = start.add(Duration(minutes: state.durationMinutes));
        final endTime = TimeOfDay.fromDateTime(end);

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                text: AppStrings.sessionDetails.tr(),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
              12.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    AppStrings.startTime.tr(),
                    startTime.format(context),
                  ),
                  Icon(
                    isArabic ? Icons.arrow_back : Icons.arrow_forward,
                    color: AppColors.textSecondary,
                    size: 18.sp,
                  ),
                  _buildSummaryItem(
                    AppStrings.endTime.tr(),
                    endTime.format(context),
                  ),
                ],
              ),
              Divider(height: 24.h, color: AppColors.divider),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText(
                    text: AppStrings.duration.tr(),
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                  AppText(
                    text: state.getFormattedDuration(isArabic),
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(text: label, fontSize: 12.sp, color: AppColors.textSecondary),
        4.verticalSpace,
        AppText(
          text: value,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.startTime != current.startTime ||
          previous.durationMinutes != current.durationMinutes ||
          previous.selectedDate != current.selectedDate ||
          previous.playMode != current.playMode ||
          previous.extraControllersCount != current.extraControllersCount,
      builder: (context, state) {
        final isReady = state.startTime != null;

        // Clean state-level price calculations
        final total = state.calculateTotalPrice(widget.params);
        final originalTotal = state.calculateOriginalTotalPrice(widget.params);
        final appliedRate = state.calculateAppliedRate(widget.params);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: const BoxDecoration(
            color: AppColors.scaffoldBackground,
            border: Border(top: BorderSide(color: AppColors.borderDefault)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        text: AppStrings.totalPrice.tr(),
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.params.room.hasActivePromo) ...[
                            Text(
                              "${originalTotal.toInt()} ${AppStrings.egp.tr()}",
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 10.sp,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          PriceWidget(
                            price: total,
                            fontSize: 24.sp,
                            color: widget.params.room.hasActivePromo
                                ? AppColors.success
                                : AppColors.neonBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 180.w,
                    child: AppButton(
                      content: ButtonContent(
                        label: _isVerifying
                            ? null
                            : AppStrings.confirmAndPay.tr(),
                        body: _isVerifying
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  AppText(
                                    text: AppStrings.processing.tr(),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                                ],
                              )
                            : null,
                      ),
                      behavior: ButtonBehavior.tap(
                        isEnabled: isReady && !_isVerifying,
                        onTap: (isReady && !_isVerifying)
                            ? () async {
                                setState(() => _isVerifying = true);
                                final cubit = context.read<BookingCubit>();
                                final isAvailable = await cubit
                                    .verifyAvailabilityBeforeProceed();
                                if (mounted) {
                                  setState(() => _isVerifying = false);
                                }
                                if (!isAvailable || !context.mounted) return;

                                context.pushNamed(
                                  RouterKeys.checkout,
                                  extra: {
                                    'lounge': widget.params.lounge,
                                    'room': widget.params.room,
                                    'date': state.selectedDate,
                                    'startTime': state.startTime!,
                                    'duration': state.durationMinutes,
                                    'totalPrice': total,
                                    'originalTotalPrice': originalTotal,
                                    'addOns': widget.params.extras,
                                    'playMode': state.playMode.name,
                                    'appliedHourlyRate': appliedRate,
                                    'extraControllers':
                                        state.extraControllersCount,
                                    'extraControllerPrice':
                                        widget.params.room.extraControllerPrice,
                                  },
                                );
                              }
                            : null,
                      ),
                      buttonConfig: ButtonConfig(
                        backgroundColor: (isReady && !_isVerifying)
                            ? AppColors.success
                            : AppColors.cardBackground,
                        borderRadius: AppSizes.r12,
                      ),
                    ),
                  ),
                ],
              ),
              const SafeBottomSpacer(extraPadding: 10),
            ],
          ),
        );
      },
    );
  }
}

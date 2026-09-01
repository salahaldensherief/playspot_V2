import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../../art_core/router/router_keys.dart';
import '../../../art_core/widgets/layout/safe_bottom_spacer.dart';
import '../domain/repositories/booking_repository.dart';
import 'booking_cubit.dart';
import 'booking_state.dart';
import 'widgets/time_slot_grid.dart';
import 'widgets/duration_selector.dart';

class BookingScreen extends StatefulWidget {
  final BookingDetailsParams params;

  const BookingScreen({
    super.key,
    required this.params,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingCubit, BookingState>(
      listenWhen: (previous, current) => 
          (previous.startTime != current.startTime && current.startTime != null) ||
          (previous.durationMinutes != current.durationMinutes),
      listener: (context, state) {
        // Scroll down when a time slot is selected or duration is changed
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
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
            text: "${AppStrings.book.tr()} ${widget.params.room.getDisplayTitle(context.locale.languageCode == 'ar')}",
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
        if (state.startTime == null) return const SizedBox.shrink();

        final start = DateTime(2000, 1, 1, state.startTime!.hour, state.startTime!.minute);
        final end = start.add(Duration(minutes: state.durationMinutes));
        final endTime = TimeOfDay.fromDateTime(end);

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                text: "sessionDetails".tr(),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
              12.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    "startTime".tr(),
                    state.startTime!.format(context),
                  ),
                  Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 16.sp),
                  _buildSummaryItem(
                    "endTime".tr(),
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
                    text: "${state.durationMinutes / 60.0} ${"hour_plural".tr(args: [''])}",
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
        AppText(
          text: label,
          fontSize: 12.sp,
          color: AppColors.textSecondary,
        ),
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
        final extrasPrice = widget.params.extras.fold<double>(
            0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));
        
        final appliedRate = state.playMode == PlayMode.single 
            ? widget.params.room.effectivePriceSingle 
            : widget.params.room.effectivePriceMulti;
            
        final extraControllersCharge = state.extraControllersCount * widget.params.room.extraControllerPrice;
        
        final durationInHours = state.durationMinutes / 60.0;
        final total = ((appliedRate + extraControllersCharge) * durationInHours) + extrasPrice;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: const BoxDecoration(
            color: AppColors.scaffoldBackground,
            border: Border(
              top: BorderSide(color: AppColors.borderDefault),
            ),
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
                               "${(((state.playMode == PlayMode.single ? widget.params.room.pricePerHourSingle : widget.params.room.pricePerHourMulti) + extraControllersCharge) * durationInHours + extrasPrice).toInt()} ${AppStrings.egp.tr()}",
                               style: TextStyle(
                                 color: AppColors.textSecondary.withOpacity(0.5),
                                 fontSize: 10.sp,
                                 decoration: TextDecoration.lineThrough,
                               ),
                             ),
                          ],
                          PriceWidget(
                            price: total,
                            fontSize: 24.sp,
                            color: widget.params.room.hasActivePromo ? AppColors.success : AppColors.neonBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 180.w,
                    child: AppButton(
                      content: ButtonContent(
                        label: AppStrings.confirmAndPay.tr(),
                      ),
                      behavior: ButtonBehavior.tap(
                        isEnabled: isReady,
                        onTap: isReady
                            ? () {
                                final appliedRate = state.playMode == PlayMode.single 
                                    ? widget.params.room.effectivePriceSingle 
                                    : widget.params.room.effectivePriceMulti;
                                    
                                final originalRate = state.playMode == PlayMode.single 
                                    ? widget.params.room.pricePerHourSingle 
                                    : widget.params.room.pricePerHourMulti;
                                    
                                final originalTotal = ((originalRate + extraControllersCharge) * durationInHours) + extrasPrice;

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
                                    'extraControllers': state.extraControllersCount,
                                    'extraControllerPrice': widget.params.room.extraControllerPrice,
                                  },
                                );
                              }
                            : null,
                      ),
                      buttonConfig: ButtonConfig(
                        backgroundColor:
                            isReady ? AppColors.success : AppColors.cardBackground,
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

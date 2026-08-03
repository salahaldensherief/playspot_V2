import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../../art_core/router/router_keys.dart';
import '../../../core/di/modules/auth_module.dart';
import '../data/repos/booking_repo.dart';
import 'booking_cubit.dart';
import 'booking_state.dart';
import 'widgets/date_selector.dart';
import 'widgets/time_slot_grid.dart';
import 'widgets/duration_selector.dart';

class BookingScreen extends StatelessWidget {
  final LoungeModel? lounge;
  final RoomModel? room;
  final DateTime? initialDate;
  final List<Map<String, dynamic>> addOns;

  const BookingScreen({
    super.key,
     this.lounge,
     this.room,
    this.initialDate,
    this.addOns = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return BlocProvider(
      create: (context) => BookingCubit(sl<BookingRepository>(), room!.id, lounge!.id, initialDate),
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
          text: "Book ${room!.getName(isArabic)}",
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: AppStrings.selectTime.tr(),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  SizedBox(height: 16.h),
                  const TimeSlotGrid(),
                  SizedBox(height: 24.h),
                  AppText(
                    text: AppStrings.duration.tr(),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  SizedBox(height: 16.h),
                  const DurationSelector(),
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

  Widget _buildBottomBar(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      builder: (context, state) {
        final isReady = state.startTime != null;
        final extrasPrice = addOns.fold<double>(0, (sum, item) => sum + (item['price'] * item['quantity']));
        final total = (room!.pricePerHour * state.durationHours) + extrasPrice;

        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            border: const Border(
              top: BorderSide(color: AppColors.borderDefault),
            ),
          ),
          child: SafeArea(
            child: Row(
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
                    PriceWidget(
                      price: total,
                      fontSize: 24.sp,
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
                              context.pushNamed(
                                RouterKeys.checkout,
                                extra: {
                                  'lounge': lounge,
                                  'room': room,
                                  'date': state.selectedDate,
                                  'startTime': state.startTime!,
                                  'duration': state.durationHours,
                                  'totalPrice': total,
                                  'addOns': addOns,
                                },
                              );
                            }
                          : null,
                    ),
                    buttonConfig: ButtonConfig(
                      backgroundColor: isReady
                          ? AppColors.success
                          : AppColors.cardBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

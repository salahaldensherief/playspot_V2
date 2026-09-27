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
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import '../../../../core/di.dart';
import '../../data/models/booking_model.dart';
import '../quick_rebook_cubit.dart';
import '../quick_rebook_state.dart';

class QuickRebookBottomSheet extends StatelessWidget {
  final BookingModel booking;

  const QuickRebookBottomSheet({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, BookingModel booking) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => sl<QuickRebookCubit>()..initQuickRebook(booking),
        child: QuickRebookBottomSheet(booking: booking),
      ),
    );
  }

  void _proceedToQuickCheckout(BuildContext context, QuickRebookState state) {
    if (state.lounge == null || state.room == null || state.selectedSlot == null) return;

    final isArabic = context.locale.languageCode == 'ar';

    final addonsList = state.selectedAddonQuantities.entries.map((entry) {
      final extra = state.availableExtras.firstWhere(
        (e) => e.id == entry.key,
      );
      return {
        'id': extra.id,
        'extra_id': extra.id,
        'name': isArabic ? extra.nameAr : extra.nameEn,
        'name_ar': extra.nameAr,
        'name_en': extra.nameEn,
        'quantity': entry.value,
        'unit_price': extra.price,
        'total_price': extra.price * entry.value,
      };
    }).toList();

    final checkoutParams = CheckoutParams(
      lounge: state.lounge!,
      rooms: [state.room!],
      roomsBreakdown: [
        {
          'roomId': state.room!.id,
          'roomName': state.room!.getDisplayTitle(isArabic),
          'originalSubtotal': state.roomSubtotal,
          'discountedSubtotal': state.roomSubtotal,
          'discountAmount': 0.0,
          'playMode': state.pastBooking?.playMode ?? 'single',
        }
      ],
      date: state.selectedDate,
      startTime: state.selectedSlot!,
      duration: state.durationMinutes,
      originalRoomSubtotal: state.roomSubtotal,
      discountedRoomSubtotal: state.roomSubtotal,
      discountAmount: 0.0,
      discountPercentage: 0.0,
      addonsTotal: state.addonsTotal,
      totalPrice: state.totalPrice,
      originalTotalPrice: state.totalPrice,
      addOns: addonsList,
      playMode: state.pastBooking?.playMode ?? 'single',
    );

    Navigator.pop(context);
    context.pushNamed(RouterKeys.checkout, extra: checkoutParams);
  }

  void _navigateToCustomize(BuildContext context, QuickRebookState state) {
    if (state.lounge == null || state.room == null) return;

    final isArabic = context.locale.languageCode == 'ar';

    final addonsList = state.selectedAddonQuantities.entries.map((entry) {
      final extra = state.availableExtras.firstWhere(
        (e) => e.id == entry.key,
      );
      return {
        'id': extra.id,
        'extra_id': extra.id,
        'name': isArabic ? extra.nameAr : extra.nameEn,
        'quantity': entry.value,
        'unit_price': extra.price,
        'total_price': extra.price * entry.value,
      };
    }).toList();

    final bookingDetailsParams = BookingDetailsParams(
      lounge: state.lounge!,
      rooms: [state.room!],
      selectedDate: state.selectedDate,
      extras: addonsList,
      playMode: state.pastBooking?.playMode ?? 'single',
      extraControllers: state.pastBooking?.controllersCount ?? 0,
    );

    Navigator.pop(context);
    context.pushNamed(RouterKeys.bookingDetails, extra: bookingDetailsParams);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return GlassContainer(
      borderRadius: 28,
      child: Container(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 16.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground.withValues(alpha: 0.96),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
        ),
        child: BlocBuilder<QuickRebookCubit, QuickRebookState>(
          builder: (context, state) {
            if (state.status == QuickRebookStatus.loading ||
                state.status == QuickRebookStatus.initial) {
              return SizedBox(
                height: 280.h,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLoader(size: 40),
                    SizedBox(height: 16.h),
                    AppText(
                      text: isArabic ? "جاري التحقق من الإتاحة والأسعار الحالية..." : "Checking availability & current prices...",
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              );
            }

            if (state.status == QuickRebookStatus.error ||
                state.status == QuickRebookStatus.unavailable) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_rounded, color: AppColors.warning, size: 48.sp),
                    SizedBox(height: 12.h),
                    AppText(
                      text: isArabic ? "عفواً، تعذر الحجز السريع المباشر" : "Quick Rebook Unavailable",
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    SizedBox(height: 6.h),
                    AppText(
                      text: state.errorMessage ?? (isArabic ? "الغرفة أو الموعد غير متاح حالياً" : "The requested room is currently unavailable."),
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20.h),
                    AppButton(
                      content: ButtonContent(
                        label: isArabic ? "استعراض الصالة والحجز العادي" : "Browse Lounge & Book",
                      ),
                      buttonConfig: ButtonConfig(
                        height: 44.h,
                        backgroundColor: AppColors.neonBlue,
                        borderRadius: 12.r,
                      ),
                      behavior: ButtonBehavior.tap(
                        onTap: () {
                          Navigator.pop(context);
                          if (booking.loungeId != null && booking.loungeId!.isNotEmpty) {
                            context.pushNamed(
                              RouterKeys.loungeDetails,
                              extra: {'loungeId': booking.loungeId},
                            );
                          } else {
                            context.goNamed(RouterKeys.home);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 16.h),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: AppColors.neonBlue,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              text: AppStrings.quickRebookTitle.tr(),
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            SizedBox(height: 2.h),
                            AppText(
                              text: AppStrings.quickRebookSubtitle.tr(),
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20.sp),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),

                  // Previous Setup Summary Card
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded, color: AppColors.neonBlue, size: 16.sp),
                            SizedBox(width: 8.w),
                            AppText(
                              text: "${state.lounge?.name ?? booking.loungeName} • ${state.room?.getDisplayTitle(isArabic) ?? booking.roomName}",
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(Icons.gamepad_outlined, color: AppColors.textSecondary, size: 14.sp),
                            SizedBox(width: 6.w),
                            AppText(
                              text: "${state.pastBooking?.playMode == 'multi' ? (isArabic ? 'زوجي (Multi)' : 'Multiplayer') : (isArabic ? 'فردي (Single)' : 'Single Player')} • ${state.durationMinutes ~/ 60} ${isArabic ? 'ساعة' : 'Hrs'}",
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Removed Addons Warning Notice (if any items no longer exist)
                  if (state.removedAddonNames.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: AppText(
                              text: isArabic
                                  ? "بعض المشروبات/السناكس غير متوفرة حالياً وتم استبعادها: ${state.removedAddonNames.join(', ')}"
                                  : "Unavailable items removed: ${state.removedAddonNames.join(', ')}",
                              fontSize: 11.sp,
                              color: AppColors.warning,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Available Slots Section
                  AppText(
                    text: isArabic ? "أقرب المواعيد المتاحة اليوم" : "Nearest Available Slots Today",
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10.h),
                  if (state.availableSlots.isEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: AppColors.textSecondary, size: 16.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: AppText(
                              text: isArabic ? "لا توجد مواعيد متاحة باقي اليوم، اختار تاريخ آخر" : "No slots remaining today.",
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      height: 42.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.availableSlots.length,
                        separatorBuilder: (_, _) => SizedBox(width: 8.w),
                        itemBuilder: (context, index) {
                          final slot = state.availableSlots[index];
                          final isSelected = state.selectedSlot == slot;

                          return GestureDetector(
                            onTap: () => context.read<QuickRebookCubit>().selectSlot(slot),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.neonBlue.withValues(alpha: 0.2)
                                    : AppColors.backgroundAlt,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                                ),
                              ),
                              child: Center(
                                child: AppText(
                                  text: slot.format(context),
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.neonBlue : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(height: 18.h),

                  // Canteen Addons Section
                  if (state.availableExtras.isNotEmpty) ...[
                    AppText(
                      text: AppStrings.previousAddons.tr(),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: AppColors.borderDefault.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: state.availableExtras.map((extra) {
                          final qty = state.selectedAddonQuantities[extra.id] ?? 0;
                          final extraName = isArabic ? extra.nameAr : extra.nameEn;

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            child: Row(
                              children: [
                                Icon(Icons.local_cafe_outlined, color: AppColors.textSecondary, size: 16.sp),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        text: extraName,
                                        fontSize: 12.sp,
                                        color: Colors.white,
                                      ),
                                      AppText(
                                        text: "${extra.price.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}",
                                        fontSize: 10.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),

                                // Quantity Controls
                                Row(
                                  children: [
                                    if (qty > 0) ...[
                                      InkWell(
                                        onTap: () => context.read<QuickRebookCubit>().updateAddonQuantity(extra.id, qty - 1),
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(6.r),
                                          ),
                                          child: Icon(Icons.remove, color: Colors.white, size: 14.sp),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                                        child: AppText(
                                          text: "$qty",
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                    InkWell(
                                      onTap: () => context.read<QuickRebookCubit>().updateAddonQuantity(extra.id, qty + 1),
                                      child: Container(
                                        padding: EdgeInsets.all(4.w),
                                        decoration: BoxDecoration(
                                          color: AppColors.neonBlue.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Icon(Icons.add, color: AppColors.neonBlue, size: 14.sp),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 18.h),
                  ],

                  // Real Price Summary Box
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          text: isArabic ? "الإجمالي الحقيقي الآن" : "Current Authoritative Total",
                          fontSize: 13.sp,
                          color: Colors.white70,
                        ),
                        AppText(
                          text: "${state.totalPrice.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}",
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonBlue,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Actions Row: Primary Quick Checkout & Secondary Customize
                  Column(
                    children: [
                      AppButton(
                        content: ButtonContent(
                          label: AppStrings.instantCheckout.tr(),
                          icon: Icon(Icons.flash_on_rounded, color: Colors.black, size: 18.sp),
                        ),
                        buttonConfig: ButtonConfig(
                          height: 48.h,
                          backgroundColor: state.selectedSlot != null ? AppColors.neonBlue : Colors.white24,
                          borderRadius: 14.r,
                        ),
                        behavior: ButtonBehavior.tap(
                          isEnabled: state.selectedSlot != null,
                          onTap: state.selectedSlot != null ? () => _proceedToQuickCheckout(context, state) : null,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      AppButton(
                        content: ButtonContent(
                          label: isArabic ? "تخصيص الحجز والتاريخ" : "Customize Booking & Date",
                        ),
                        buttonConfig: ButtonConfig(
                          height: 42.h,
                          backgroundColor: Colors.transparent,
                          borderColor: AppColors.borderDefault,
                          borderRadius: 12.r,
                        ),
                        behavior: ButtonBehavior.tap(
                          onTap: () => _navigateToCustomize(context, state),
                        ),
                      ),
                    ],
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

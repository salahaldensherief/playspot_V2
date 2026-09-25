import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class TimeSlotGrid extends StatefulWidget {
  final LoungeModel lounge;

  const TimeSlotGrid({
    super.key,
    required this.lounge,
  });

  @override
  State<TimeSlotGrid> createState() => _TimeSlotGridState();
}

class _TimeSlotGridState extends State<TimeSlotGrid> {
  // Playtomic Shift Filter (0: All, 1: Morning, 2: Evening, 3: Night)
  int _shiftFilter = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.bookedTimeSlots != current.bookedTimeSlots ||
          previous.startTime != current.startTime ||
          previous.durationMinutes != current.durationMinutes ||
          previous.selectedDate != current.selectedDate,
      builder: (context, state) {
        if (state.status == BookingStatus.loading && state.bookedTimeSlots.isEmpty) {
          return SizedBox(
            height: 100.h,
            child: const AppLoader(size: 30),
          );
        }

        // Generate future slots ONLY (Past slots are completely excluded)
        final slots = _generateFutureSlots(
          widget.lounge.openingTime,
          widget.lounge.closingTime,
          state,
        );

        if (slots.isEmpty) {
          return _buildFullyBookedOrPastBanner(context);
        }

        // 🚀 AUTO-SET INITIAL VALUE TO NEAREST AVAILABLE SLOT
        if (state.startTime == null) {
          final firstAvailable = slots.firstWhere(
            (s) => !_isSlotBooked(s, state),
            orElse: () => slots.first,
          );
          if (!_isSlotBooked(firstAvailable, state)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && context.read<BookingCubit>().state.startTime == null) {
                context.read<BookingCubit>().selectStartTime(firstAvailable);
              }
            });
          }
        }

        // Determine which shifts actually have remaining future slots today
        final hasMorning = slots.any((s) => s.hour >= 6 && s.hour < 16);
        final hasAfternoon = slots.any((s) => s.hour >= 16 && s.hour < 22);
        final hasNight = slots.any((s) => s.hour >= 22 || s.hour < 6);

        // Reset filter if active shift filter tab is no longer available today
        if (_shiftFilter == 1 && !hasMorning) _shiftFilter = 0;
        if (_shiftFilter == 2 && !hasAfternoon) _shiftFilter = 0;
        if (_shiftFilter == 3 && !hasNight) _shiftFilter = 0;

        final availableShiftCount = (hasMorning ? 1 : 0) + (hasAfternoon ? 1 : 0) + (hasNight ? 1 : 0);

        // Filter slots according to active shift tab
        List<TimeOfDay> filteredSlots = slots;
        if (_shiftFilter == 1 && hasMorning) {
          filteredSlots = slots.where((s) => s.hour >= 6 && s.hour < 16).toList();
        } else if (_shiftFilter == 2 && hasAfternoon) {
          filteredSlots = slots.where((s) => s.hour >= 16 && s.hour < 22).toList();
        } else if (_shiftFilter == 3 && hasNight) {
          filteredSlots = slots.where((s) => s.hour >= 22 || s.hour < 6).toList();
        }
        if (filteredSlots.isEmpty) filteredSlots = slots;

        final selectedStart = state.startTime;
        final maxFreeHours = selectedStart != null
            ? _calculateMaxContinuousFreeHours(selectedStart, slots, state)
            : 0.0;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Shift Filter Bar Header (Only show tabs for remaining future shifts!)
              if (availableShiftCount > 1) ...[
                Row(
                  children: [
                    _buildShiftFilterChip(0, AppStrings.all.tr()),
                    if (hasMorning) ...[
                      SizedBox(width: 6.w),
                      _buildShiftFilterChip(1, "☀️ ${'morning'.tr()}"),
                    ],
                    if (hasAfternoon) ...[
                      SizedBox(width: 6.w),
                      _buildShiftFilterChip(2, "🌆 ${'afternoon'.tr()}"),
                    ],
                    if (hasNight) ...[
                      SizedBox(width: 6.w),
                      _buildShiftFilterChip(3, "🌙 ${'evening'.tr()}"),
                    ],
                  ],
                ),
                SizedBox(height: 14.h),
              ],

              // Playtomic Compact Time Ribbon
              SizedBox(
                height: 52.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredSlots.length,
                  separatorBuilder: (_, _) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final slot = filteredSlots[index];
                    final isBooked = _isSlotBooked(slot, state);
                    final isSelectedStart = state.startTime?.hour == slot.hour && state.startTime?.minute == slot.minute;
                    final isInSelectionSpan = _isPartOfCurrentSelection(slot, state);

                    return InkWell(
                      onTap: isBooked ? null : () => context.read<BookingCubit>().selectStartTime(slot),
                      borderRadius: BorderRadius.circular(10.r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 76.w,
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        decoration: BoxDecoration(
                          color: isSelectedStart
                              ? AppColors.neonBlue
                              : (isInSelectionSpan
                                  ? AppColors.neonBlue.withValues(alpha: 0.25)
                                  : (isBooked
                                      ? AppColors.danger.withValues(alpha: 0.15)
                                      : Colors.black45)),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isSelectedStart
                                ? Colors.white
                                : (isInSelectionSpan
                                    ? AppColors.neonBlue
                                    : (isBooked ? AppColors.danger : AppColors.borderDefault)),
                            width: isSelectedStart ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelectedStart
                              ? [
                                  BoxShadow(
                                    color: AppColors.neonBlue.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppText(
                              text: _formatTime(slot),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: isSelectedStart
                                  ? Colors.black
                                  : (isInSelectionSpan
                                      ? AppColors.neonBlue
                                      : (isBooked ? AppColors.danger : Colors.white)),
                              textDecoration: isBooked ? TextDecoration.lineThrough : null,
                            ),
                            if (isBooked) ...[
                              SizedBox(height: 2.h),
                              AppText(
                                text: AppStrings.booked.tr(),
                                fontSize: 8.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ] else if (isSelectedStart) ...[
                              SizedBox(height: 2.h),
                              AppText(
                                text: "start".tr(),
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 14.h),

              // Playtomic Instant Status & Availability Preview Card
              if (selectedStart != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              text: "${AppStrings.startTime.tr()}: ${_formatTime(selectedStart)}",
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                            SizedBox(height: 2.h),
                            AppText(
                              text: "${AppStrings.available.tr()} ${maxFreeHours.toStringAsFixed(1)} ${AppStrings.hour_plural.tr()}",
                              fontSize: 10.sp,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftFilterChip(int index, String label) {
    final isSelected = _shiftFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _shiftFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.2) : Colors.black26,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: AppText(
              text: label,
              fontSize: 10.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Slot Generation: Exclude Past Slots Completely ──────────────────
  List<TimeOfDay> _generateFutureSlots(String openStr, String closeStr, BookingState state) {
    int start = _parseHour(openStr, 10);
    int end = _parseHour(closeStr, 2);

    if (end <= start) {
      end += 24;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day);
    final isToday = selectedDate.isAtSameMomentAs(today);
    final isPastDate = selectedDate.isBefore(today);

    if (isPastDate) return [];

    final List<TimeOfDay> list = [];
    for (int h = start; h < end; h++) {
      final hourMod = h % 24;
      for (int m = 0; m < 60; m += 15) {
        final slot = TimeOfDay(hour: hourMod, minute: m);

        // Completely skip slots that are in the past if date is today
        if (isToday) {
          var slotDateTime = DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
          if (slot.hour < 6) slotDateTime = slotDateTime.add(const Duration(days: 1));
          if (slotDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
            continue; // Skip past slots!
          }
        }

        list.add(slot);
      }
    }
    return list;
  }

  // ─── Helpers & Range Span Math ────────────────────────────────────────
  bool _isSlotBooked(TimeOfDay slot, BookingState state) {
    return state.bookedTimeSlots.any((b) => b.hour == slot.hour && b.minute == slot.minute);
  }

  double _calculateMaxContinuousFreeHours(TimeOfDay start, List<TimeOfDay> allSlots, BookingState state) {
    final startIndex = allSlots.indexWhere((s) => s.hour == start.hour && s.minute == start.minute);
    if (startIndex == -1) return 0.0;

    int count = 0;
    for (int i = startIndex; i < allSlots.length; i++) {
      if (_isSlotBooked(allSlots[i], state)) break;
      count++;
    }
    return (count * 15) / 60.0;
  }

  bool _isPartOfCurrentSelection(TimeOfDay slot, BookingState state) {
    if (state.startTime == null) return false;

    final startMinutes = state.startTime!.hour * 60 + state.startTime!.minute;
    final slotMinutes = slot.hour * 60 + slot.minute;

    int normalizedStart = startMinutes;
    if (startMinutes < (6 * 60)) normalizedStart += (24 * 60);

    int normalizedSlot = slotMinutes;
    if (slotMinutes < (6 * 60)) normalizedSlot += (24 * 60);

    final normalizedEnd = normalizedStart + state.durationMinutes;

    return normalizedSlot >= normalizedStart && normalizedSlot < normalizedEnd;
  }

  Widget _buildFullyBookedOrPastBanner(BuildContext context) {
    final isEnglish = context.locale.languageCode == 'en';
    final message = isEnglish
        ? 'All time slots for this date are booked or past. Please select another date.'
        : 'جميع الأوقات لهذا اليوم محجوزة أو انقضت. يرجى اختيار تاريخ آخر.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: AppText(
              text: message,
              fontSize: 12.sp,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  int _parseHour(String str, int defaultHour) {
    if (str.isEmpty) return defaultHour;
    try {
      final parts = str.split(':');
      return int.parse(parts[0]);
    } catch (_) {
      return defaultHour;
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "$hour:$minute $period";
  }
}

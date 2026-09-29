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

  const TimeSlotGrid({super.key, required this.lounge});

  @override
  State<TimeSlotGrid> createState() => _TimeSlotGridState();
}

class _TimeSlotGridState extends State<TimeSlotGrid> {
  int _shiftFilter = 0;
  bool _waitlistBusy = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.bookedTimeSlots != current.bookedTimeSlots ||
          previous.slotPrices != current.slotPrices ||
          previous.startTime != current.startTime ||
          previous.durationMinutes != current.durationMinutes ||
          previous.selectedDate != current.selectedDate,
      builder: (context, state) {
        if (state.status == BookingStatus.loading &&
            state.bookedTimeSlots.isEmpty) {
          return SizedBox(height: 100.h, child: const AppLoader(size: 30));
        }

        // Generate future slots
        final slots = _generateFutureSlots(
          widget.lounge.openingTime,
          widget.lounge.closingTime,
          state,
        );

        if (slots.isEmpty) {
          return _buildFullyBookedOrPastBanner(context);
        }

        // AUTO-SET INITIAL VALUE TO NEAREST AVAILABLE SLOT
        if (state.startTime == null) {
          final firstAvailable = slots.firstWhere(
            (s) => !_isSlotBooked(s, state),
            orElse: () => slots.first,
          );
          if (!_isSlotBooked(firstAvailable, state)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  context.read<BookingCubit>().state.startTime == null) {
                context.read<BookingCubit>().selectStartTime(firstAvailable);
              }
            });
          }
        }

        final hasMorning = slots.any((s) => s.hour >= 6 && s.hour < 16);
        final hasAfternoon = slots.any((s) => s.hour >= 16 && s.hour < 22);
        final hasNight = slots.any((s) => s.hour >= 22 || s.hour < 6);

        if (_shiftFilter == 1 && !hasMorning) _shiftFilter = 0;
        if (_shiftFilter == 2 && !hasAfternoon) _shiftFilter = 0;
        if (_shiftFilter == 3 && !hasNight) _shiftFilter = 0;

        final availableShiftCount =
            (hasMorning ? 1 : 0) + (hasAfternoon ? 1 : 0) + (hasNight ? 1 : 0);

        List<TimeOfDay> filteredSlots = slots;
        if (_shiftFilter == 1 && hasMorning) {
          filteredSlots = slots
              .where((s) => s.hour >= 6 && s.hour < 16)
              .toList();
        } else if (_shiftFilter == 2 && hasAfternoon) {
          filteredSlots = slots
              .where((s) => s.hour >= 16 && s.hour < 22)
              .toList();
        } else if (_shiftFilter == 3 && hasNight) {
          filteredSlots = slots
              .where((s) => s.hour >= 22 || s.hour < 6)
              .toList();
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
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              // Time Slot Ribbon with Price and Peak Tag
              SizedBox(
                height: 68.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredSlots.length,
                  separatorBuilder: (_, _) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final slot = filteredSlots[index];
                    final isBooked = _isSlotBooked(slot, state);
                    final slotPrice = state.getSlotPrice(slot);
                    final isPeak = slotPrice?.isPeak ?? false;
                    final rateVal = slotPrice?.hourlyRate;

                    final isSelectedStart =
                        state.startTime?.hour == slot.hour &&
                        state.startTime?.minute == slot.minute;
                    final isInSelectionSpan = _isPartOfCurrentSelection(
                      slot,
                      state,
                    );

                    return InkWell(
                      onTap: isBooked
                          ? (context.read<BookingCubit>().roomIds.length == 1
                                ? () => _requestWaitlist(context, slot)
                                : null)
                          : () => context.read<BookingCubit>().selectStartTime(
                              slot,
                            ),
                      borderRadius: BorderRadius.circular(10.r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 82.w,
                        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                        decoration: BoxDecoration(
                          color: isSelectedStart
                              ? AppColors.neonBlue
                              : (isInSelectionSpan
                                    ? AppColors.neonBlue.withValues(alpha: 0.25)
                                    : (isBooked
                                          ? AppColors.danger.withValues(
                                              alpha: 0.15,
                                            )
                                          : (isPeak
                                              ? AppColors.warning.withValues(alpha: 0.12)
                                              : Colors.black45))),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isSelectedStart
                                ? Colors.white
                                : (isInSelectionSpan
                                      ? AppColors.neonBlue
                                      : (isBooked
                                            ? AppColors.danger
                                            : (isPeak
                                                ? AppColors.warning.withValues(alpha: 0.6)
                                                : AppColors.borderDefault))),
                            width: isSelectedStart ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelectedStart
                              ? [
                                  BoxShadow(
                                    color: AppColors.neonBlue.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
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
                                        : (isBooked
                                              ? AppColors.danger
                                              : Colors.white)),
                              textDecoration: isBooked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            SizedBox(height: 2.h),
                            if (isBooked) ...[
                              AppText(
                                text: context.read<BookingCubit>().roomIds.length == 1
                                    ? AppStrings.waitlistNotify.tr()
                                    : AppStrings.booked.tr(),
                                fontSize: 8.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ] else ...[
                              if (rateVal != null && rateVal > 0)
                                AppText(
                                  text: "${rateVal.toStringAsFixed(0)} ${isArabic ? 'ج.م/س' : 'EGP/h'}",
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isSelectedStart
                                      ? Colors.black87
                                      : (isPeak ? AppColors.warning : Colors.white70),
                                ),
                              if (isPeak) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: AppText(
                                    text: AppStrings.peak.tr(),
                                    fontSize: 7.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ] else if (isSelectedStart) ...[
                                AppText(
                                  text: "start".tr(),
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 14.h),

              if (selectedStart != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.neonBlue.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              text:
                                  "${AppStrings.startTime.tr()}: ${_formatTime(selectedStart)}",
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                            SizedBox(height: 2.h),
                            AppText(
                              text:
                                  "${AppStrings.available.tr()} ${maxFreeHours.toStringAsFixed(1)} ${AppStrings.hour_plural.tr()}",
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
            color: isSelected
                ? AppColors.neonBlue.withValues(alpha: 0.2)
                : Colors.black26,
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

  List<TimeOfDay> _generateFutureSlots(
    String openStr,
    String closeStr,
    BookingState state,
  ) {
    int start = _parseHour(openStr, 10);
    int end = _parseHour(closeStr, 2);

    if (end <= start) {
      end += 24;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );
    final isToday = selectedDate.isAtSameMomentAs(today);
    final isPastDate = selectedDate.isBefore(today);

    if (isPastDate) return [];

    final List<TimeOfDay> list = [];
    for (int h = start; h < end; h++) {
      final hourMod = h % 24;
      for (int m = 0; m < 60; m += 15) {
        final slot = TimeOfDay(hour: hourMod, minute: m);

        if (isToday) {
          var slotDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            slot.hour,
            slot.minute,
          );
          if (slot.hour < 6) {
            slotDateTime = slotDateTime.add(const Duration(days: 1));
          }
          if (slotDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
            continue;
          }
        }

        // Rule #2: if slotPrices is available and slot price rate <= 0 (unpriced slot), hide it!
        if (state.slotPrices.isNotEmpty) {
          final slotPrice = state.getSlotPrice(slot);
          if (slotPrice != null && !slotPrice.isValidPriced) {
            continue; // Hide slot!
          }
        }

        list.add(slot);
      }
    }
    return list;
  }

  bool _isSlotBooked(TimeOfDay slot, BookingState state) {
    return state.bookedTimeSlots.any(
      (b) => b.hour == slot.hour && b.minute == slot.minute,
    );
  }

  double _calculateMaxContinuousFreeHours(
    TimeOfDay start,
    List<TimeOfDay> allSlots,
    BookingState state,
  ) {
    final startIndex = allSlots.indexWhere(
      (s) => s.hour == start.hour && s.minute == start.minute,
    );
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

  Future<void> _requestWaitlist(BuildContext context, TimeOfDay slot) async {
    if (_waitlistBusy) return;
    _waitlistBusy = true;
    try {
      final cubit = context.read<BookingCubit>();
      final (loaded, activeId) = await cubit.activeWaitlistRequest(slot);
      if (!mounted) return;
      if (!loaded) {
        _showWaitlistMessage(AppStrings.waitlistFailed);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            (activeId == null
                    ? AppStrings.waitlistNotify
                    : AppStrings.waitlistCancel)
                .tr(),
          ),
          content: Text(
            (activeId == null
                    ? AppStrings.waitlistExplain
                    : AppStrings.waitlistCancelExplain)
                .tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.cancel.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                (activeId == null
                        ? AppStrings.waitlistNotify
                        : AppStrings.waitlistCancel)
                    .tr(),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final messageKey = activeId == null
          ? await cubit.joinWaitlist(slot)
          : await cubit.cancelWaitlist(activeId);
      if (!mounted) return;
      _showWaitlistMessage(messageKey);
    } finally {
      _waitlistBusy = false;
    }
  }

  void _showWaitlistMessage(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(key.tr())));
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

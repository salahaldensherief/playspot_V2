import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({super.key});

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
        if (state.status == BookingStatus.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
        }

        // Divide slots into tactical shifts
        final morningSlots = _generateSlots(10, 16); // 10 AM to 4 PM
        final eveningSlots = _generateSlots(16, 22); // 4 PM to 10 PM
        final nightSlots = _generateSlots(22, 26);   // 10 PM to 2 AM (next day)

        return Column(
          children: [
            _buildTimeSection(context, "☀️ Morning Shift", morningSlots, state),
            SizedBox(height: 24.h),
            _buildTimeSection(context, "🌆 Evening Shift", eveningSlots, state),
            SizedBox(height: 24.h),
            _buildTimeSection(context, "🌌 Night Ops", nightSlots, state),
          ],
        );
      },
    );
  }

  List<TimeOfDay> _generateSlots(int startHour, int endHour) {
    final List<TimeOfDay> slots = [];
    for (int h = startHour; h < endHour; h++) {
      slots.add(TimeOfDay(hour: h % 24, minute: 0));
      slots.add(TimeOfDay(hour: h % 24, minute: 30));
    }
    return slots;
  }

  Widget _buildTimeSection(BuildContext context, String title, List<TimeOfDay> slots, BookingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: AppText(
            text: title.toUpperCase(),
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        Wrap(
          spacing: 10.w,
          runSpacing: 12.h,
          children: slots.map((slot) => _buildTacticalChip(context, slot, state)).toList(),
        ),
      ],
    );
  }

  Widget _buildTacticalChip(BuildContext context, TimeOfDay slot, BookingState state) {
    final isBooked = state.bookedTimeSlots.any((s) => s.hour == slot.hour && s.minute == slot.minute);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day);
    bool isPast = selectedDate.isBefore(today);
    if (selectedDate.isAtSameMomentAs(today)) {
      var slotDateTime = DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
      if (slot.hour < 10) slotDateTime = slotDateTime.add(const Duration(days: 1));
      isPast = slotDateTime.isBefore(now.add(const Duration(minutes: 5)));
    }

    final isDisabled = isBooked || isPast;
    final isSelected = state.startTime?.hour == slot.hour && state.startTime?.minute == slot.minute;

    bool isPartOfCurrentSelection = false;
    if (state.startTime != null && !isPast) {
      final startMinutes = state.startTime!.hour * 60 + state.startTime!.minute;
      final currentMinutes = slot.hour * 60 + slot.minute;
      
      int normalizedStart = startMinutes;
      if (startMinutes < (10 * 60)) normalizedStart += (24 * 60);
      
      int normalizedCurrent = currentMinutes;
      if (currentMinutes < (10 * 60)) normalizedCurrent += (24 * 60);
      
      final normalizedEnd = normalizedStart + state.durationMinutes;
      
      isPartOfCurrentSelection = normalizedCurrent >= normalizedStart && normalizedCurrent < normalizedEnd;
    }

    return InkWell(
      onTap: isDisabled ? null : () => context.read<BookingCubit>().selectStartTime(slot),
      borderRadius: BorderRadius.circular(8.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 82.w,
        height: 44.h,
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.neonBlue.withValues(alpha: 0.9) 
              : (isPartOfCurrentSelection 
                  ? AppColors.neonBlue.withValues(alpha: 0.2)
                  : (isBooked
                      ? AppColors.danger.withValues(alpha: 0.08)
                      : (isPast ? Colors.white.withValues(alpha: 0.02) : AppColors.cardBackground))),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected 
                ? AppColors.white 
                : (isPartOfCurrentSelection 
                    ? AppColors.neonBlue.withValues(alpha: 0.5) 
                    : (isBooked
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : (isPast ? Colors.transparent : AppColors.borderDefault))),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.neonBlue.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            )
          ] : (isPartOfCurrentSelection ? [
            BoxShadow(
              color: AppColors.neonBlue.withValues(alpha: 0.1),
              blurRadius: 4,
            )
          ] : null),
        ),
        child: Stack(
          children: [
            if (isSelected) ...[
              Positioned(top: 4, left: 4, child: _hudCorner(0)),
              Positioned(bottom: 4, right: 4, child: _hudCorner(2)),
            ],
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(
                    text: _formatTime(slot),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    textDecoration: isBooked ? TextDecoration.lineThrough : null,
                    color: isSelected 
                        ? AppColors.black 
                        : (isPartOfCurrentSelection 
                            ? AppColors.neonBlue 
                            : (isBooked
                                ? AppColors.danger.withValues(alpha: 0.7)
                                : (isPast ? AppColors.textSecondary.withValues(alpha: 0.2) : AppColors.white))),
                  ),
                  if (isBooked) ...[
                    SizedBox(height: 1.h),
                    AppText(
                      text: AppStrings.occupied.tr(),
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger.withValues(alpha: 0.8),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudCorner(int quarter) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        border: Border(
          top: quarter == 0 ? const BorderSide(color: Colors.black, width: 1.5) : BorderSide.none,
          left: quarter == 0 ? const BorderSide(color: Colors.black, width: 1.5) : BorderSide.none,
          bottom: quarter == 2 ? const BorderSide(color: Colors.black, width: 1.5) : BorderSide.none,
          right: quarter == 2 ? const BorderSide(color: Colors.black, width: 1.5) : BorderSide.none,
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute == 0 ? "00" : "30";
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "$hour:$minute $period";
  }
}

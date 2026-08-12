import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // Generate 1 hour slots from 10:00 AM to 2:00 AM (next day)
    final slots = List.generate(17, (index) {
      int hour = (10 + index) % 24;
      return TimeOfDay(hour: hour, minute: 0);
    });

    return BlocBuilder<BookingCubit, BookingState>(
      builder: (context, state) {
        if (state.status == BookingStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            mainAxisExtent: 50.h,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            
            // 🕒 Check if slot is in the past
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final selectedDate = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day);
            
            bool isPastDate = selectedDate.isBefore(today);
            bool isToday = selectedDate.isAtSameMomentAs(today);
            
            bool isPast = isPastDate;
            if (isToday) {
              var slotDateTime = DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
              // Handle midnight crossover (slots 00:00 - 09:00 belong to the next calendar day morning)
              if (slot.hour < 10) {
                slotDateTime = slotDateTime.add(const Duration(days: 1));
              }
              isPast = slotDateTime.isBefore(now.add(const Duration(minutes: 5)));
            }

            final isBooked = state.bookedTimeSlots.any((s) => s.hour == slot.hour);
            final isDisabled = isBooked || isPast;
            final isSelected = state.startTime?.hour == slot.hour;
            
            // Checking if the CURRENT selection (startTime + duration) would overlap this slot
            // This is for visual feedback
            bool isPartOfCurrentSelection = false;
            if (state.startTime != null && !isPast) {
              final startHour = state.startTime!.hour;
              final currentHour = slot.hour;
              // Handle next day overlap (e.g. 23:00 to 01:00)
              final endHour = (startHour + state.durationHours) % 24;
              
              if (startHour < endHour) {
                isPartOfCurrentSelection = currentHour >= startHour && currentHour < endHour;
              } else {
                // Overlaps midnight
                isPartOfCurrentSelection = currentHour >= startHour || currentHour < endHour;
              }
            }

            return GestureDetector(
              onTap: isDisabled ? null : () => context.read<BookingCubit>().selectStartTime(slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.neonBlue 
                      : (isPartOfCurrentSelection 
                          ? AppColors.neonBlue.withOpacity(0.2)
                          : (isDisabled ? Colors.white.withOpacity(0.02) : AppColors.cardBackground)),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.neonBlue 
                        : (isDisabled ? Colors.white.withOpacity(0.05) : AppColors.borderDefault),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      text: _formatTime(slot),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                          ? AppColors.black 
                          : (isDisabled ? AppColors.textSecondary.withOpacity(0.3) : AppColors.white),
                      textDecoration: isDisabled ? TextDecoration.lineThrough : null,
                    ),
                    if (isBooked)
                      AppText(
                        text: AppStrings.booked.tr(),
                        fontSize: 8.sp,
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    if (isPast && !isBooked)
                      AppText(
                        text: "PAST",
                        fontSize: 8.sp,
                        color: AppColors.textSecondary.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "$hour:00 $period";
  }
}

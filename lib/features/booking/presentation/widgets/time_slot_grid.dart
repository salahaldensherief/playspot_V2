import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            final isBooked = state.bookedTimeSlots.any((s) => s.hour == slot.hour);
            final isSelected = state.startTime?.hour == slot.hour;
            
            // Checking if the CURRENT selection (startTime + duration) would overlap this slot
            // This is for visual feedback
            bool isPartOfCurrentSelection = false;
            if (state.startTime != null) {
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
              onTap: isBooked ? null : () => context.read<BookingCubit>().selectStartTime(slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.neonBlue 
                      : (isPartOfCurrentSelection 
                          ? AppColors.neonBlue.withOpacity(0.2)
                          : (isBooked ? AppColors.danger.withOpacity(0.05) : AppColors.cardBackground)),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.neonBlue 
                        : (isBooked ? AppColors.danger.withOpacity(0.3) : AppColors.borderDefault),
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
                          : (isBooked ? AppColors.danger : AppColors.white),
                      textDecoration: isBooked ? TextDecoration.lineThrough : null,
                    ),
                    if (isBooked)
                      AppText(
                        text: "Booked",
                        fontSize: 8.sp,
                        color: AppColors.danger,
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

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
            final isBooked = context.read<BookingCubit>().isSlotBooked(slot);
            final isSelected = state.startTime?.hour == slot.hour;
            final isAvailable = context.read<BookingCubit>().isSlotAvailable(slot);

            return GestureDetector(
              onTap: (!isBooked && isAvailable) 
                  ? () => context.read<BookingCubit>().selectStartTime(slot) 
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.neonBlue.withOpacity(0.1) : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.neonBlue 
                        : (isBooked ? AppColors.danger.withOpacity(0.3) : AppColors.borderDefault),
                  ),
                ),
                alignment: Alignment.center,
                child: AppText(
                  text: _formatTime(slot),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected 
                      ? AppColors.neonBlue 
                      : (isBooked ? AppColors.danger : AppColors.white),
                  textDecoration: isBooked ? TextDecoration.lineThrough : null,
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

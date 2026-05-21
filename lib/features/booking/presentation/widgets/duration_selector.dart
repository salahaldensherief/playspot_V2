import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class DurationSelector extends StatelessWidget {
  const DurationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 28.sp),
                onPressed: () => context.read<BookingCubit>().updateDuration(-1),
              ),
              SizedBox(width: 24.w),
              Column(
                children: [
                  AppText(
                    text: state.durationHours.toString(),
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonBlue,
                  ),
                  AppText(
                    text: "hour",
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              SizedBox(width: 24.w),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: AppColors.neonBlue, size: 28.sp),
                onPressed: () => context.read<BookingCubit>().updateDuration(1),
              ),
            ],
          ),
        );
      },
    );
  }
}

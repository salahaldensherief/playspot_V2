import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dates = List.generate(14, (index) => now.add(Duration(days: index)));

    return SizedBox(
      height: 100.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isToday = index == 0;
          final isSelected = selectedDate.day == date.day && 
                             selectedDate.month == date.month &&
                             selectedDate.year == date.year;

          return _DateItem(
            date: date,
            isSelected: isSelected,
            isToday: isToday,
            onTap: () => onDateSelected(date),
          );
        },
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _DateItem({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75.w,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.transparent : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withValues(alpha: 0.1),
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
              text: DateFormat('EEE').format(date),
              fontSize: 12.sp,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(height: 4.h),
            AppText(
              text: date.day.toString(),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.neonBlue : AppColors.white,
            ),
            if (isToday) ...[
              SizedBox(height: 4.h),
              AppText(
                text: "Today",
                fontSize: 10.sp,
                color: AppColors.neonBlue,
                fontWeight: FontWeight.w600,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

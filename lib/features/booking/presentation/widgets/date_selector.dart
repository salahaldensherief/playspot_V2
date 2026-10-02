import 'date_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      height: 104 * MediaQuery.textScalerOf(context).scale(1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isToday = index == 0;
          final isSelected =
              selectedDate.day == date.day &&
              selectedDate.month == date.month &&
              selectedDate.year == date.year;

          return DateItem(
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

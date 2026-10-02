import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class DateItem extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const DateItem({
    super.key,
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
        width: 96 * MediaQuery.textScalerOf(context).scale(1),
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
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(
              text: DateFormat(
                'EEE',
                context.locale.toLanguageTag(),
              ).format(date),
              fontSize: 12,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(height: 4.h),
            AppText(
              text: date.day.toString(),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.neonBlue : AppColors.white,
            ),
            if (isToday) ...[
              SizedBox(height: 4.h),
              AppText(
                text: AppStrings.today.tr(),
                fontSize: 10,
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

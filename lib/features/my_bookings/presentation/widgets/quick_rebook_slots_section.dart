import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../quick_rebook_cubit.dart';
import '../quick_rebook_state.dart';

class QuickRebookSlotsSection extends StatelessWidget {
  final QuickRebookState state;

  const QuickRebookSlotsSection({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(today.year, today.month, today.day + 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked != null && context.mounted) {
              await context.read<QuickRebookCubit>().changeDate(picked);
            }
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            DateFormat.yMMMEd(context.locale.languageCode)
                .format(state.selectedDate),
          ),
        ),
        SizedBox(height: 10.h),
        AppText(
          text: AppStrings.quickRebookNearestSlots.tr(),
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        SizedBox(height: 10.h),
        if (state.availableSlots.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: AppColors.textSecondary,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppText(
                    text: AppStrings.quickRebookNoSlots.tr(),
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 42.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.availableSlots.length,
              separatorBuilder: (_, _) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final slot = state.availableSlots[index];
                final isSelected = state.selectedSlot == slot;

                return GestureDetector(
                  onTap: () =>
                      context.read<QuickRebookCubit>().selectSlot(slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonBlue.withValues(alpha: 0.2)
                          : AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonBlue
                            : AppColors.borderDefault,
                      ),
                    ),
                    child: Center(
                      child: AppText(
                        text: slot.format(context),
                        fontSize: 12.sp,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.neonBlue
                            : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

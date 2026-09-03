import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';

class ActionCard extends StatelessWidget {
  final String label;
  final int mins;
  final double cost;
  final bool isLoading;

  const ActionCard({
    super.key,
    required this.label,
    required this.mins,
    required this.cost,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading
              ? null
              : () => context
                  .read<ActiveSessionCubit>()
                  .extendTime(mins, cost),
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.neonBlue.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  text: label,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: AppColors.textPrimary,
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: AppText(
                    text: "${cost.toInt()} ${AppStrings.egpSymbol.tr()}",
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

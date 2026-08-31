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
    return InkWell(
      onTap: isLoading ? null : () => context.read<ActiveSessionCubit>().extendTime(mins, cost),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 105.w,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            AppText(text: label, fontWeight: FontWeight.bold, fontSize: 14.sp),
            SizedBox(height: 4.h),
            AppText(
              text: "${cost.toInt()} ${AppStrings.egpSymbol.tr()}",
              fontSize: 12.sp,
              color: AppColors.neonBlue,
            ),
          ],
        ),
      ),
    );
  }
}

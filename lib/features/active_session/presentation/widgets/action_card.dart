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

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.withOpacity(AppColors.neonBlue, 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.withOpacity(AppColors.neonBlue, 0.3),
                  ),
                ),
                child: Icon(
                  Icons.add_alarm_rounded,
                  color: AppColors.neonBlue,
                  size: 38.sp,
                ),
              ),
              SizedBox(height: 16.h),
              AppText(
                text: AppStrings.confirmExtensionTitle.tr(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              AppText(
                text: AppStrings.confirmExtensionSubtitle.tr(args: [label, cost.toInt().toString()]),
                fontSize: 13.5.sp,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: AppText(
                        text: AppStrings.cancel.tr(),
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context
                            .read<ActiveSessionCubit>()
                            .extendTime(mins, cost);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonBlue,
                        foregroundColor: AppColors.black,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: AppText(
                        text: AppStrings.next.tr(),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _showConfirmationDialog(context),
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.withOpacity(AppColors.neonBlue, 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.withOpacity(AppColors.black, 0.15),
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
                    color: AppColors.withOpacity(AppColors.neonBlue, 0.08),
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

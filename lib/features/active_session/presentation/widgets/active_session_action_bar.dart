import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'staff_call_bottom_sheet.dart';
import 'menu_bottom_sheet.dart';

class ActiveSessionActionBar extends StatelessWidget {
  const ActiveSessionActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) =>
          prev.staffRequestStatus != curr.staffRequestStatus,
      builder: (context, state) {
        final isStaffLoading = state.staffRequestStatus == ActionStatus.loading;

        return Row(
          children: [
            // Call Staff Action Card
            Expanded(
              flex: 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: isStaffLoading
                      ? null
                      : () => _showStaffCallBottomSheet(context),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 56.h),
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF261D12),
                          const Color(0xFF18130D),
                        ],
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: isStaffLoading
                                ? SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.warning,
                                    ),
                                  )
                                : Icon(
                                    Icons.support_agent_rounded,
                                    color: AppColors.warning,
                                    size: 20.sp,
                                  ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                text: AppStrings.callStaff.tr(),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  Container(
                                    width: 5.w,
                                    height: 5.w,
                                    decoration: const BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: AppText(
                                      text: AppStrings.helpSupport.tr(),
                                      fontSize: 10.sp,
                                      color: AppColors.warning.withValues(
                                        alpha: 0.8,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(width: 10.w),

            // Order Extras / Canteen Launcher Card
            Expanded(
              flex: 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () => _showMenuBottomSheet(context),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 56.h),
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2D114B),
                          const Color(0xFF121B35),
                        ],
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.neonPurple.withValues(alpha: 0.7),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPurple.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.neonPurple,
                                AppColors.neonBlue,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonPurple.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.fastfood_rounded,
                              color: Colors.white,
                              size: 19.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                text: AppStrings.orderExtras.tr(),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 11.sp,
                                    color: AppColors.neonBlue,
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: AppText(
                                      text: AppStrings.canteenMenu.tr(),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neonBlue,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11.sp,
                          color: AppColors.neonBlue.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showStaffCallBottomSheet(BuildContext context) {
    final cubit = context.read<ActiveSessionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StaffCallBottomSheet(
        onSubmit: (type, notes) => cubit.requestStaffAssistance(type, notes),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context) {
    final cubit = context.read<ActiveSessionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MenuBottomSheet(cubit: cubit),
    );
  }
}

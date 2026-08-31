import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'staff_call_bottom_sheet.dart';
import 'menu_bottom_sheet.dart';

class ActiveSessionActionBar extends StatelessWidget {
  const ActiveSessionActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) => prev.staffRequestStatus != curr.staffRequestStatus,
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: AppButton(
                content: ButtonContent(
                  label: AppStrings.callStaff.tr(),
                  icon: Icon(Icons.notifications_active_outlined, color: AppColors.white, size: 20.sp),
                ),
                buttonConfig: ButtonConfig(
                  height: 54.h,
                  backgroundColor: AppColors.warning.withOpacity(0.1),
                  borderColor: AppColors.warning.withOpacity(0.5),
                  textStyle: TextStyle(
                    color: AppColors.warning,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                behavior: TapBehavior(
                  isEnabled: state.staffRequestStatus != ActionStatus.loading,
                  onTap: () => _showStaffCallBottomSheet(context),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AppButton(
                content: ButtonContent(
                  label: AppStrings.orderExtras.tr(),
                  icon: Icon(Icons.fastfood_rounded, color: AppColors.white, size: 20.sp),
                ),
                buttonConfig: ButtonConfig(
                  height: 54.h,
                  backgroundColor: AppColors.neonPurple,
                  glowColor: AppColors.neonPurple,
                ),
                behavior: TapBehavior(
                  isEnabled: true,
                  onTap: () => _showMenuBottomSheet(context),
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

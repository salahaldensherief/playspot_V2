import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';

class _StaffOption {
  final String id;
  final String label;
  final IconData icon;

  const _StaffOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class StaffCallBottomSheet extends StatefulWidget {
  final Function(String type, String? notes) onSubmit;

  const StaffCallBottomSheet({super.key, required this.onSubmit});

  @override
  State<StaffCallBottomSheet> createState() => _StaffCallBottomSheetState();
}

class _StaffCallBottomSheetState extends State<StaffCallBottomSheet> {
  String _selectedType = 'assistance';
  final TextEditingController _notesController = TextEditingController();

  static const List<_StaffOption> _types = [
    _StaffOption(
      id: 'assistance',
      label: AppStrings.assistance,
      icon: Icons.support_agent_rounded,
    ),
    _StaffOption(
      id: 'cleaning',
      label: AppStrings.cleaning,
      icon: Icons.cleaning_services_rounded,
    ),
    _StaffOption(
      id: 'controller_issue',
      label: AppStrings.controllerIssue,
      icon: Icons.sports_esports_rounded,
    ),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 16.h,
        bottom: 24.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            20.verticalSpace,
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.room_service_rounded,
                    color: AppColors.neonBlue,
                    size: 22.sp,
                  ),
                ),
                12.horizontalSpace,
                AppText(
                  text: AppStrings.callStaff.tr(),
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
            20.verticalSpace,
            ..._types.map((type) => _buildTypeOption(type)),
            16.verticalSpace,
            AppTextField(
              controller: _notesController,
              hint: AppStrings.addNote.tr(),
              maxLines: 2,
              borderRadius: 16.r,
            ),
            24.verticalSpace,
            AppButton(
              content: ButtonContent(label: AppStrings.continueText.tr()),
              behavior: TapBehavior(
                isEnabled: true,
                onTap: () {
                  final noteText = _notesController.text.trim();
                  widget.onSubmit(
                    _selectedType,
                    noteText.isEmpty ? null : noteText,
                  );
                  Navigator.pop(context);
                },
              ),
              buttonConfig: ButtonConfig(
                width: double.infinity,
                gradient: AppColors.primaryGradient,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(_StaffOption type) {
    final isSelected = _selectedType == type.id;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedType = type.id);
          },
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.neonBlue.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.neonBlue.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.neonBlue.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    type.icon,
                    color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                    size: 20.sp,
                  ),
                ),
                14.horizontalSpace,
                Expanded(
                  child: AppText(
                    text: type.label.tr(),
                    fontSize: 15.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

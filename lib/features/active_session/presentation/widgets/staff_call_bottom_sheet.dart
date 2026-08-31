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

class StaffCallBottomSheet extends StatefulWidget {
  final Function(String type, String? notes) onSubmit;

  const StaffCallBottomSheet({super.key, required this.onSubmit});

  @override
  State<StaffCallBottomSheet> createState() => _StaffCallBottomSheetState();
}

class _StaffCallBottomSheetState extends State<StaffCallBottomSheet> {
  String _selectedType = 'assistance';
  final _notesController = TextEditingController();

  final List<Map<String, dynamic>> _types = [
    {'id': 'assistance', 'label': AppStrings.assistance},
    {'id': 'cleaning', 'label': AppStrings.cleaning},
    {'id': 'controller_issue', 'label': AppStrings.controllerIssue},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24.r), // Standardize with top only if needed, but here it's fine
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          24.verticalSpace,
          AppText(
            text: AppStrings.callStaff.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          24.verticalSpace,
          ..._types.map((type) => _buildTypeOption(type)),
          24.verticalSpace,
          AppTextField(
            controller: _notesController,
            hint: AppStrings.addNote.tr(),
            maxLines: 2,
            borderRadius: 16.r,
          ),
          32.verticalSpace,
          AppButton(
            content: ButtonContent(label: AppStrings.continueText.tr()),
            behavior: TapBehavior(
              isEnabled: true,
              onTap: () {
                widget.onSubmit(_selectedType, _notesController.text.trim().isEmpty ? null : _notesController.text.trim());
                Navigator.pop(context);
              },
            ),
            buttonConfig: ButtonConfig(
              width: double.infinity,
              gradient: AppColors.primaryGradient,
            ),
          ),
          MediaQuery.of(context).viewInsets.bottom.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildTypeOption(Map<String, dynamic> type) {
    final isSelected = _selectedType == type['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type['id']!),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
              size: 20.sp,
            ),
            SizedBox(width: 16.w),
            AppText(
              text: (type['label'] as String).tr(),
              fontSize: 16.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

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

class LoungeReviewBottomSheet extends StatefulWidget {
  final String loungeName;
  final Function(double rating, String? comment) onSubmit;

  const LoungeReviewBottomSheet({
    super.key,
    required this.loungeName,
    required this.onSubmit,
  });

  @override
  State<LoungeReviewBottomSheet> createState() => _LoungeReviewBottomSheetState();
}

class _LoungeReviewBottomSheetState extends State<LoungeReviewBottomSheet> {
  double _rating = 5;
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          24.verticalSpace,
          AppText(
            text: AppStrings.rateExperience.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          12.verticalSpace,
          AppText(
            text: AppStrings.howWasYourSession.tr(args: [widget.loungeName]),
            fontSize: 14.sp,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          32.verticalSpace,
          _buildRatingBar(),
          32.verticalSpace,
          AppTextField(
            controller: _commentController,
            hint: AppStrings.feedbackHint.tr(),
            maxLines: 3,
            borderRadius: 16.r,
          ),
          32.verticalSpace,
          AppButton(
            content: ButtonContent(label: AppStrings.submitReview.tr()),
            behavior: TapBehavior(
              isEnabled: true,
              onTap: () {
                widget.onSubmit(_rating, _commentController.text.trim().isEmpty ? null : _commentController.text.trim());
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

  Widget _buildRatingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        return GestureDetector(
          onTap: () => setState(() => _rating = starValue),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Icon(
              Icons.star_rounded,
              size: 48.sp,
              color: starValue <= _rating ? AppColors.warning : Colors.white.withOpacity(0.1),
            ),
          ),
        );
      }),
    );
  }
}

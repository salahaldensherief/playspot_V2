import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/rating/interactive_rating_input.dart';
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
  double _rating = 5.0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(double rating) {
    if (rating >= 4.5) return AppStrings.ratingExcellent.tr();
    if (rating >= 3.5) return AppStrings.ratingVeryGood.tr();
    if (rating >= 2.5) return AppStrings.ratingGood.tr();
    if (rating >= 1.5) return AppStrings.ratingFair.tr();
    return AppStrings.ratingPoor.tr();
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return AppColors.warning;
    if (rating >= 3.0) return Colors.amber;
    if (rating >= 2.0) return Colors.orange;
    return AppColors.danger;
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
            AppText(
              text: AppStrings.rateExperience.tr(),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            8.verticalSpace,
            AppText(
              text: AppStrings.howWasYourSession.tr(args: [widget.loungeName]),
              fontSize: 14.sp,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            24.verticalSpace,
            _buildRatingBar(),
            12.verticalSpace,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  text: _rating.toStringAsFixed(1),
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: _getRatingColor(_rating),
                ),
                8.horizontalSpace,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _getRatingColor(_rating).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _getRatingColor(_rating).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: AppText(
                    text: _getRatingLabel(_rating),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _getRatingColor(_rating),
                  ),
                ),
              ],
            ),
            24.verticalSpace,
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
                isEnabled: _rating > 0,
                onTap: () {
                  if (_rating <= 0) return;
                  final comment = _commentController.text.trim();
                  widget.onSubmit(
                    _rating,
                    comment.isEmpty ? null : comment,
                  );
                  GameHudToast.show(
                    context,
                    AppStrings.reviewSubmittedSuccess.tr(),
                    type: ToastType.success,
                  );
                  Navigator.pop(context);
                },
              ),
              buttonConfig: ButtonConfig(
                width: double.infinity,
                gradient: _rating > 0 ? AppColors.primaryGradient : null,
                backgroundColor: AppColors.backgroundAlt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar() {
    return Center(
      child: InteractiveRatingInput(
        initialRating: _rating,
        starSize: 44.sp,
        spacing: 8.w,
        onRatingChanged: (newRating) {
          setState(() {
            _rating = newRating;
          });
        },
      ),
    );
  }
}

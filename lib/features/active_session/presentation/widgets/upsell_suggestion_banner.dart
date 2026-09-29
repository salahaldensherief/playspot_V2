import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/images/app_images.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../domain/entities/order_item.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';

class UpsellSuggestionBanner extends StatefulWidget {
  const UpsellSuggestionBanner({super.key});

  @override
  State<UpsellSuggestionBanner> createState() => _UpsellSuggestionBannerState();
}

class _UpsellSuggestionBannerState extends State<UpsellSuggestionBanner> {
  String? _recordedSuggestionId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) =>
          prev.upsellSuggestions != curr.upsellSuggestions ||
          prev.upsellImpressionsCount != curr.upsellImpressionsCount,
      builder: (context, state) {
        if (state.upsellSuggestions.isEmpty || state.upsellImpressionsCount >= 2) {
          return const SizedBox.shrink();
        }

        final suggestion = state.upsellSuggestions.first;
        final cubit = context.read<ActiveSessionCubit>();

        // Record impression once when rendered
        if (_recordedSuggestionId != suggestion.ruleId) {
          _recordedSuggestionId = suggestion.ruleId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              cubit.recordUpsellImpression(suggestion);
            }
          });
        }

        final isArabic = context.locale.languageCode == 'ar';
        final title = suggestion.getName(isArabic);
        final price = suggestion.finalPrice;
        final imageUrl = suggestion.imageUrl;

        return Container(
          width: double.infinity,
          margin: EdgeInsetsDirectional.only(bottom: 16.h),
          padding: EdgeInsetsDirectional.all(12.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.neonPurple.withValues(alpha: 0.15),
                AppColors.neonBlue.withValues(alpha: 0.1),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.neonPurple.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                AppImage(
                  urlImg: imageUrl,
                  width: 44.w,
                  height: 44.w,
                  fit: BoxFit.cover,
                  borderRadius: 10.r,
                ),
                SizedBox(width: 10.w),
              ] else ...[
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    suggestion.isCombo ? Icons.fastfood_rounded : Icons.local_cafe_rounded,
                    color: AppColors.neonPurple,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsetsDirectional.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: AppText(
                            text: AppStrings.specialOffer.tr(),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neonPurple,
                          ),
                        ),
                        if (suggestion.discountPercent > 0) ...[
                          SizedBox(width: 6.w),
                          AppText(
                            text: "-${suggestion.discountPercent.toInt()}%",
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.h),
                    AppText(
                      text: title,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppText(
                      text: "${price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonBlue,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              AppButton(
                content: ButtonContent(
                  label: AppStrings.addSuggestion.tr(),
                  icon: Icon(Icons.add, size: 14.sp, color: AppColors.white),
                ),
                behavior: TapBehavior(
                  isEnabled: true,
                  onTap: () {
                    cubit.acceptUpsellSuggestion(suggestion);
                    final orderItem = OrderItem(
                      id: suggestion.targetId,
                      name: title,
                      nameAr: suggestion.nameAr,
                      nameEn: suggestion.nameEn,
                      price: price,
                      quantity: 1,
                      isCombo: suggestion.isCombo,
                    );
                    cubit.placeOrder([orderItem]);
                  },
                ),
                buttonConfig: ButtonConfig(
                  height: 34.h,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  backgroundColor: AppColors.neonPurple,
                  borderRadius: 10.r,
                  textStyle: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18.sp, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.w),
                onPressed: () => cubit.dismissUpsellSuggestion(suggestion),
              ),
            ],
          ),
        );
      },
    );
  }
}

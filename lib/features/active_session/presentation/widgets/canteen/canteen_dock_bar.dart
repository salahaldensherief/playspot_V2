import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class CanteenDockBar extends StatelessWidget {
  final int totalCount;
  final double total;
  final bool isLoading;
  final VoidCallback onOrder;

  const CanteenDockBar({
    super.key,
    required this.totalCount,
    required this.total,
    required this.isLoading,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.only(
        start: 18.w,
        end: 18.w,
        top: 14.h,
        bottom: 18.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101320),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: totalCount > 0
                      ? "$totalCount ${AppStrings.cart.tr()}"
                      : AppStrings.cartEmpty.tr(),
                  fontSize: 11.5.sp,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                AppText(
                  text:
                      "${total.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonBlue,
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            flex: 2,
            child: AppButton(
              content: ButtonContent(
                label: AppStrings.confirmOrder.tr(),
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18.sp,
                  color: Colors.white,
                ),
              ),
              behavior: TapBehavior(
                isEnabled: totalCount > 0 && !isLoading,
                isLoading: isLoading,
                onTap: onOrder,
              ),
              buttonConfig: ButtonConfig(
                height: 50.h,
                backgroundColor: totalCount > 0
                    ? AppColors.neonPurple
                    : const Color(0xFF1F2230),
                glowColor: totalCount > 0
                    ? AppColors.neonPurple
                    : Colors.transparent,
                borderRadius: 14.r,
                textStyle: TextStyle(
                  color: totalCount > 0
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

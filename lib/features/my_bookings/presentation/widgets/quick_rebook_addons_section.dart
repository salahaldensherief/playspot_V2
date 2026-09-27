import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../quick_rebook_cubit.dart';
import '../quick_rebook_state.dart';

class QuickRebookAddonsSection extends StatelessWidget {
  final QuickRebookState state;

  const QuickRebookAddonsSection({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (state.availableExtras.isEmpty) {
      return const SizedBox.shrink();
    }

    final isArabic = context.locale.languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          text: AppStrings.previousAddons.tr(),
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.borderDefault.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: state.availableExtras.map((extra) {
              final quantity =
                  state.selectedAddonQuantities[extra.id] ?? 0;
              final name = isArabic ? extra.nameAr : extra.nameEn;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_cafe_outlined,
                      color: AppColors.textSecondary,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            text: name,
                            fontSize: 12.sp,
                            color: Colors.white,
                          ),
                          AppText(
                            text:
                                '${extra.price.toStringAsFixed(0)} ${AppStrings.egp.tr()}',
                            fontSize: 10.sp,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    if (quantity > 0) ...[
                      _buildQuantityButton(
                        context,
                        icon: Icons.remove,
                        onTap: () => context
                            .read<QuickRebookCubit>()
                            .updateAddonQuantity(
                              extra.id,
                              quantity - 1,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: AppText(
                          text: quantity.toString(),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    _buildQuantityButton(
                      context,
                      icon: Icons.add,
                      isPrimary: true,
                      onTap: () => context
                          .read<QuickRebookCubit>()
                          .updateAddonQuantity(
                            extra.id,
                            quantity + 1,
                          ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.neonBlue.withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Icon(
          icon,
          color: isPrimary ? AppColors.neonBlue : Colors.white,
          size: 14.sp,
        ),
      ),
    );
  }
}

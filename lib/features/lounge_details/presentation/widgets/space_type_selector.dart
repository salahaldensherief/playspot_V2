import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class SpaceTypeSelector extends StatelessWidget {
  const SpaceTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final List<Map<String, dynamic>> spaceTypes = [
      {'id': 'all', 'label': AppStrings.all.tr(), 'icon': Icons.grid_view, 'color': AppColors.neonBlue},
      {'id': 'open_area', 'label': AppStrings.openArea.tr(), 'icon': Icons.monitor, 'color': AppColors.neonBlue},
      {'id': 'standard_room', 'label': AppStrings.standardRoom.tr(), 'icon': Icons.meeting_room, 'color': AppColors.neonPurple},
      {'id': 'vip_room', 'label': AppStrings.vipRoom.tr(), 'icon': Icons.stars, 'color': AppColors.warning},
      {'id': 'simulator', 'label': isArabic ? "سيموليتر" : "Simulator", 'icon': Icons.speed, 'color': AppColors.cyan},
      {'id': 'vr', 'label': "VR", 'icon': Icons.view_in_ar, 'color': AppColors.neonPurple},
    ];

    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) => previous.selectedSpaceType != current.selectedSpaceType,
      builder: (context, state) {
        return Container(
          height: 45.h,
          margin: EdgeInsets.symmetric(vertical: 12.h),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            itemCount: spaceTypes.length,
            itemBuilder: (context, index) {
              final type = spaceTypes[index];
              final isSelected = state.selectedSpaceType == type['id'];
              final themeColor = type['color'] as Color;

              return GestureDetector(
                onTap: () => context.read<LoungeDetailsCubit>().setSpaceType(type['id']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(right: 10.w),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? themeColor : AppColors.borderDefault,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: themeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 18.sp,
                        color: isSelected ? AppColors.black : themeColor,
                      ),
                      SizedBox(width: 8.w),
                      AppText(
                        text: type['label']!,
                        fontSize: 13.sp,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.black : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

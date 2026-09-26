import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class SpaceTypeSelector extends StatelessWidget {
  const SpaceTypeSelector({super.key});

  static const List<String> _orderedKeys = [
    'all',
    'vip_room',
    'standard_room',
    'open_area',
    'simulator',
    'vr',
  ];

  static const Map<String, IconData> _spaceTypeIcons = {
    'all': Icons.grid_view,
    'vip_room': Icons.stars,
    'standard_room': Icons.meeting_room,
    'open_area': Icons.monitor,
    'simulator': Icons.speed,
    'vr': Icons.view_in_ar,
  };

  static const Map<String, Color> _spaceTypeColors = {
    'all': AppColors.neonBlue,
    'vip_room': AppColors.warning,
    'standard_room': AppColors.neonPurple,
    'open_area': AppColors.neonBlue,
    'simulator': AppColors.cyan,
    'vr': AppColors.neonPurple,
  };

  static String _getSpaceTypeLabel(String key) {
    switch (key) {
      case 'all':
        return AppStrings.all.tr();
      case 'vip_room':
        return AppStrings.vipRoom.tr();
      case 'standard_room':
        return AppStrings.standardRoom.tr();
      case 'open_area':
        return AppStrings.openArea.tr();
      case 'simulator':
        return AppStrings.simulator.tr();
      case 'vr':
        return AppStrings.vr.tr();
      default:
        if (kDebugMode) {
          debugPrint("⚠️ SpaceTypeSelector: Unrecognized space type key '$key' from database.");
        }
        // Fallback: Format raw snake_case/slug into human-readable Title Case
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) =>
          previous.selectedSpaceType != current.selectedSpaceType ||
          previous.rooms != current.rooms,
      builder: (context, state) {
        if (state.rooms.isEmpty) {
          return const SizedBox.shrink();
        }

        final availableTypeSlugs = state.rooms
            .map((room) => room.spaceTypeName?.toLowerCase().trim())
            .where((slug) => slug != null && slug.isNotEmpty)
            .toSet();

        final List<String> activeKeys = _orderedKeys
            .where((key) => key == 'all' || availableTypeSlugs.contains(key))
            .toList();

        final List<String> displayKeys =
            activeKeys.length > 1 ? activeKeys : _orderedKeys;

        return Container(
          height: 45.h,
          margin: EdgeInsets.symmetric(vertical: 12.h),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            itemCount: displayKeys.length,
            itemBuilder: (context, index) {
              final key = displayKeys[index];
              final isSelected = state.selectedSpaceType == key;
              final icon = _spaceTypeIcons[key] ?? Icons.meeting_room;
              final themeColor = _spaceTypeColors[key] ?? AppColors.neonBlue;
              final label = _getSpaceTypeLabel(key);

              return GestureDetector(
                onTap: () => context
                    .read<LoungeDetailsCubit>()
                    .setSpaceType(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsetsDirectional.only(end: 10.w),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? themeColor : AppColors.borderDefault,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 18.sp,
                        color: isSelected ? AppColors.black : themeColor,
                      ),
                      SizedBox(width: 8.w),
                      AppText(
                        text: label,
                        fontSize: 13.sp,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppColors.black
                            : AppColors.textSecondary,
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

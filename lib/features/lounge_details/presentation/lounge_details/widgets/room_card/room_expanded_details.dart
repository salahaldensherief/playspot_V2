import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'room_constants.dart';
import 'room_detail_chip.dart';
import 'room_feature_item.dart';
import 'room_gallery_button.dart';
import 'room_section_header.dart';
import 'room_spec.dart';

class RoomExpandedDetails extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isExpanded;
  final bool isSelected;
  final Color themeColor;

  const RoomExpandedDetails({
    super.key,
    required this.room,
    required this.isArabic,
    required this.isExpanded,
    required this.isSelected,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final features = room.getFeatures(isArabic);
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: Colors.white.withOpacity(0.05), height: 1.h),
            12.verticalSpace,
            if (isSelected) ...[
              _buildSelectionConfig(context),
              16.verticalSpace,
              Divider(color: Colors.white.withOpacity(0.05), height: 1.h),
              12.verticalSpace,
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RoomSectionHeader(
                    title: AppStrings.roomFeatures.tr(), themeColor: themeColor),
                if (room.images.isNotEmpty)
                  RoomGalleryButton(room: room, themeColor: themeColor),
              ],
            ),
            8.verticalSpace,
            if (features.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children:
                    features.map((f) => RoomFeatureItem(feature: f)).toList(),
              )
            else
              AppText(
                text: AppStrings.noExtrasAvailable.tr(),
                fontSize: 10.sp,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            12.verticalSpace,
            RoomSectionHeader(
                title: AppStrings.technicalSetup.tr(), themeColor: themeColor),
            8.verticalSpace,
            if (room.isSimulator) ...[
              const RoomSpec(icon: Icons.monitor, value: "Triple 32\" 4K Setup"),
              SizedBox(height: 4.h),
              const RoomSpec(
                  icon: Icons.settings_input_component,
                  value: "Fanatec DD2 + V3 Pedals"),
            ] else if (room.isVR) ...[
              const RoomSpec(icon: Icons.cable, value: "Link Cable / Wireless"),
              SizedBox(height: 4.h),
              const RoomSpec(
                  icon: Icons.games, value: "Half-Life: Alyx, Beat Saber"),
            ],
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: room.activityNames
                  .map((activity) =>
                      RoomDetailChip(label: activity, themeColor: themeColor))
                  .toList(),
            ),
          ],
        ),
      ),
      crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: RoomConstants.animationDuration,
    );
  }

  Widget _buildSelectionConfig(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (prev, curr) =>
          prev.roomPlayModes[room.id] != curr.roomPlayModes[room.id] ||
          prev.roomExtraControllers[room.id] !=
              curr.roomExtraControllers[room.id],
      builder: (context, state) {
        final playMode = state.roomPlayModes[room.id] ?? 'single';
        final extraControllers = state.roomExtraControllers[room.id] ?? 0;

        return Column(
          children: [
            if (room.isOpenArea) ...[
              _buildPlayModeToggle(context, playMode),
              12.verticalSpace,
            ],
            if (room.extraControllerPrice > 0)
              _buildExtraControllerStepper(context, extraControllers),
          ],
        );
      },
    );
  }

  Widget _buildPlayModeToggle(BuildContext context, String currentMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(
            text: AppStrings.playMode.tr(),
            fontSize: 12.sp,
            color: Colors.white70,
            fontWeight: FontWeight.bold),
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: [
              _buildToggleOption(context, 'single',
                  isArabic ? "👤 فردي" : "👤 Single", currentMode == 'single'),
              _buildToggleOption(context, 'multi',
                  isArabic ? "👥 زوجي" : "👥 Multi", currentMode == 'multi'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption(
      BuildContext context, String mode, String label, bool isSelected) {
    return GestureDetector(
      onTap: () =>
          context.read<LoungeDetailsCubit>().setRoomPlayMode(room.id, mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: AppText(
          text: label,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppColors.black : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildExtraControllerStepper(BuildContext context, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
                text: isArabic ? "دراعات إضافية" : "Extra Controllers",
                fontSize: 12.sp,
                color: Colors.white70,
                fontWeight: FontWeight.bold),
            AppText(
                text:
                    "+${room.extraControllerPrice.toInt()} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()}",
                fontSize: 9.sp,
                color: AppColors.warning.withOpacity(0.8)),
          ],
        ),
        Row(
          children: [
            _buildStepButton(Icons.remove,
                () => context.read<LoungeDetailsCubit>().updateRoomExtraControllers(room.id, -1)),
            14.horizontalSpace,
            AppText(
                text: count.toString(),
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            14.horizontalSpace,
            _buildStepButton(Icons.add,
                () => context.read<LoungeDetailsCubit>().updateRoomExtraControllers(room.id, 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(6.r),
          color: Colors.white.withOpacity(0.03),
        ),
        child: Icon(icon, size: 14.sp, color: Colors.white),
      ),
    );
  }
}

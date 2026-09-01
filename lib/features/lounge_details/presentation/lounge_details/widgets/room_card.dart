import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/full_screen_gallery.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class RoomConstants {
  static const double borderRadius = 18.0;
  static const Duration animationDuration = Duration(milliseconds: 350);
  static const Duration toggleDuration = Duration(milliseconds: 250);
}

extension RoomThemeX on RoomModel {
  Color get themeColor {
    if (isVIP) return AppColors.warning;
    if (isVR) return AppColors.neonPurple;
    if (isSimulator) return AppColors.cyan;
    return AppColors.neonBlue;
  }

  IconData get icon {
    if (isSimulator) return Icons.speed;
    if (isVR) return Icons.view_in_ar;
    if (isOpenArea) return Icons.monitor;
    if (isVIP) return Icons.stars;
    return Icons.meeting_room;
  }
}

class RoomCard extends StatefulWidget {
  final RoomModel room;
  const RoomCard({super.key, required this.room});

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final themeColor = widget.room.themeColor;

    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final isSelected = state.selectedRoomId == widget.room.id;
        final isBooked = state.bookedRoomIds.contains(widget.room.id);
        final isLoungeOpen = state.lounge?.isOpen ?? true;
        final isAvailable = widget.room.isAvailable && !isBooked && isLoungeOpen;

        return GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: AnimatedContainer(
            duration: RoomConstants.animationDuration,
            margin: EdgeInsets.only(bottom: 10.h),
            child: GlassContainer(
              borderRadius: RoomConstants.borderRadius,
              borderOpacity: (isSelected || _isExpanded) ? 0.3 : 0.05,
              useBorderColorForGradient: false,
              color: Colors.white.withOpacity(0.02),
              borderColor: isSelected
                  ? themeColor
                  : (isAvailable ? AppColors.borderDefault : AppColors.danger.withOpacity(0.15)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoomMainContent(
                    room: widget.room,
                    isArabic: isArabic,
                    isAvailable: isAvailable,
                    isSelected: isSelected,
                    isExpanded: _isExpanded,
                    themeColor: themeColor,
                  ),
                  _RoomExpandedDetails(
                    room: widget.room,
                    isArabic: isArabic,
                    isExpanded: _isExpanded,
                    isSelected: isSelected,
                    themeColor: themeColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomMainContent extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isAvailable;
  final bool isSelected;
  final bool isExpanded;
  final Color themeColor;

  const _RoomMainContent({
    required this.room,
    required this.isArabic,
    required this.isAvailable,
    required this.isSelected,
    required this.isExpanded,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoomHeader(
                        room: room,
                        isArabic: isArabic,
                        isAvailable: isAvailable,
                        isExpanded: isExpanded,
                        themeColor: themeColor,
                      ),
                      _SpaceTypeBadge(room: room, isArabic: isArabic, themeColor: themeColor),
                      _QuickSpecs(room: room),
                    ],
                  ),
                ),
              ),
              _RoomActionArea(room: room, isAvailable: isAvailable, isSelected: isSelected, themeColor: themeColor),
            ],
          ),
          if (!isAvailable) const _BookedOverlay(),
        ],
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isAvailable;
  final bool isExpanded;
  final Color themeColor;

  const _RoomHeader({
    required this.room,
    required this.isArabic,
    required this.isAvailable,
    required this.isExpanded,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(room.icon, color: themeColor, size: 20.sp),
        10.horizontalSpace,
        Expanded(
          child: AppText(
            text: room.getDisplayTitle(isArabic),
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
            color: isAvailable ? Colors.white : AppColors.textSecondary,
            maxLines: isExpanded ? 5 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: themeColor.withOpacity(0.4),
          size: 18.sp,
        ),
      ],
    );
  }
}

class _SpaceTypeBadge extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final Color themeColor;

  const _SpaceTypeBadge({required this.room, required this.isArabic, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: AppText(
        text: room.spaceTypeLabel(isArabic),
        fontSize: 7.sp,
        fontWeight: FontWeight.w900,
        color: themeColor,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _QuickSpecs extends StatelessWidget {
  final RoomModel room;
  const _QuickSpecs({required this.room});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.w,
      children: [
        if (room.isSimulator) 
          _Spec(icon: Icons.settings_input_component, value: room.activityNames.firstWhere((a) => a.toLowerCase().contains('fanatec'), orElse: () => "Pro Racing Setup"))
        else if (room.isVR)
          _Spec(icon: Icons.headset, value: room.activityNames.firstWhere((a) => a.toLowerCase().contains('quest'), orElse: () => "VR Experience"))
        else
          _Spec(icon: Icons.videogame_asset_outlined, value: "${room.controllersCount} ${AppStrings.controllers.tr()}"),

        _Spec(icon: Icons.tv, value: room.screenSize),
        if (!room.isOpenArea) _Spec(icon: Icons.people_outline, value: room.capacity.toString()),
      ],
    );
  }
}

class _Spec extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Spec({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.contains('0') && !value.contains('10')) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: AppColors.textSecondary.withOpacity(0.4)),
        SizedBox(width: 4.w),
        AppText(text: value, fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      ],
    );
  }
}

class _RoomActionArea extends StatelessWidget {
  final RoomModel room;
  final bool isAvailable;
  final bool isSelected;
  final Color themeColor;

  const _RoomActionArea({
    required this.room,
    required this.isAvailable,
    required this.isSelected,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final playMode = state.roomPlayModes[room.id] ?? 'single';
        final extraControllers = state.roomExtraControllers[room.id] ?? 0;
        
        double currentPrice = room.pricePerHour;
        if (room.isOpenArea) {
          currentPrice = playMode == 'single' ? room.pricePerHourSingle : room.pricePerHourMulti;
        }
        currentPrice += (extraControllers * room.extraControllerPrice);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.white.withOpacity(0.03))),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PriceWidget(price: currentPrice, fontSize: 16.sp, color: themeColor),
              AppText(
                text: AppStrings.perHour.tr().toUpperCase(),
                fontSize: 7.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: () => context.read<LoungeDetailsCubit>().toggleRoomSelection(room.id),
                child: AnimatedContainer(
                  duration: RoomConstants.toggleDuration,
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    boxShadow: isSelected ? [
                      BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                    ] : null,
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.add,
                    color: isSelected ? AppColors.black : Colors.white,
                    size: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BookedOverlay extends StatelessWidget {
  const _BookedOverlay();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(RoomConstants.borderRadius.r),
        ),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: AppText(
              text: AppStrings.booked.tr().toUpperCase(),
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomExpandedDetails extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isExpanded;
  final bool isSelected;
  final Color themeColor;

  const _RoomExpandedDetails({
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
                _SectionHeader(title: AppStrings.roomFeatures.tr(), themeColor: themeColor),
                if (room.images.isNotEmpty) _GalleryButton(room: room, themeColor: themeColor),
              ],
            ),
            8.verticalSpace,
            if (features.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: features.map((f) => _FeatureItem(feature: f)).toList(),
              )
            else
              AppText(
                text: isArabic ? "لا توجد تفاصيل إضافية" : "No additional features",
                fontSize: 10.sp,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            12.verticalSpace,
            _SectionHeader(title: AppStrings.technicalSetup.tr(), themeColor: themeColor),
            8.verticalSpace,
            if (room.isSimulator) ...[
              _Spec(icon: Icons.monitor, value: "Triple 32\" 4K Setup"),
              SizedBox(height: 4.h),
              _Spec(icon: Icons.settings_input_component, value: "Fanatec DD2 + V3 Pedals"),
            ] else if (room.isVR) ...[
              _Spec(icon: Icons.cable, value: "Link Cable / Wireless"),
              SizedBox(height: 4.h),
              _Spec(icon: Icons.games, value: "Half-Life: Alyx, Beat Saber"),
            ],
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: room.activityNames.map((activity) => _DetailChip(label: activity, themeColor: themeColor)).toList(),
            ),
          ],
        ),
      ),
      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: RoomConstants.animationDuration,
    );
  }

  Widget _buildSelectionConfig(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
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
        AppText(text: AppStrings.playMode.tr(), fontSize: 12.sp, color: Colors.white70, fontWeight: FontWeight.bold),
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: [
              _buildToggleOption(context, 'single', isArabic ? "👤 فردي" : "👤 Single", currentMode == 'single'),
              _buildToggleOption(context, 'multi', isArabic ? "👥 زوجي" : "👥 Multi", currentMode == 'multi'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption(BuildContext context, String mode, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => context.read<LoungeDetailsCubit>().setRoomPlayMode(room.id, mode),
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
            AppText(text: isArabic ? "دراعات إضافية" : "Extra Controllers", fontSize: 12.sp, color: Colors.white70, fontWeight: FontWeight.bold),
            AppText(
              text: "+${room.extraControllerPrice.toInt()} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()}", 
              fontSize: 9.sp, 
              color: AppColors.warning.withOpacity(0.8)
            ),
          ],
        ),
        Row(
          children: [
            _buildStepButton(Icons.remove, () => context.read<LoungeDetailsCubit>().updateRoomExtraControllers(room.id, -1)),
            14.horizontalSpace,
            AppText(text: count.toString(), fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white),
            14.horizontalSpace,
            _buildStepButton(Icons.add, () => context.read<LoungeDetailsCubit>().updateRoomExtraControllers(room.id, 1)),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color themeColor;
  const _SectionHeader({required this.title, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return AppText(
      text: title.toUpperCase(),
      fontSize: 8.sp,
      fontWeight: FontWeight.w900,
      color: themeColor.withOpacity(0.7),
      letterSpacing: 0.8,
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final RoomModel room;
  final Color themeColor;
  const _GalleryButton({required this.room, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenGallery(
          images: room.images,
          initialIndex: 0,
          heroTag: 'room_image_${room.id}',
        )));
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: themeColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 12.sp, color: themeColor),
            6.horizontalSpace,
            AppText(text: AppStrings.viewPhotos.tr(), fontSize: 9.sp, fontWeight: FontWeight.bold, color: themeColor),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color themeColor;
  const _DetailChip({required this.label, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: themeColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 10.sp, color: themeColor.withOpacity(0.5)),
          6.horizontalSpace,
          AppText(text: label, fontSize: 10.sp, color: Colors.white70),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String feature;
  const _FeatureItem({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 10.sp, color: AppColors.success.withOpacity(0.6)),
          6.horizontalSpace,
          AppText(text: feature, fontSize: 10.sp, color: Colors.white70, fontWeight: FontWeight.w500),
        ],
      ),
    );
  }
}

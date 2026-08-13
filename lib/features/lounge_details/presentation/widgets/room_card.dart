import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/text/price_widget.dart';
import '../../../../art_core/widgets/layout/full_screen_gallery.dart';
import '../../data/models/room_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class RoomConstants {
  static const double borderRadius = 18.0;
  static const Duration animationDuration = Duration(milliseconds: 350);
  static const Duration toggleDuration = Duration(milliseconds: 250);
}

extension RoomThemeX on RoomModel {
  Color get themeColor {
    final isVR = activityNames.any((a) => a.toLowerCase().contains('vr'));
    final isSimulator = activityNames.any((a) => a.toLowerCase().contains('simulator'));
    final isVIP = spaceType?.toLowerCase().contains('vip') ?? false;

    if (isVIP) return AppColors.warning;
    if (isVR) return AppColors.neonPurple;
    if (isSimulator) return AppColors.cyan;
    return AppColors.neonBlue;
  }

  String spaceTypeLabel(bool isArabic) {
    final type = spaceType ?? "OPEN";
    switch (type.toLowerCase()) {
      case 'vip':
        return isArabic ? 'غرفة VIP' : 'VIP ROOM';
      case 'private':
        return isArabic ? 'غرفة خاصة' : 'PRIVATE ROOM';
      case 'open':
        return isArabic ? 'مساحة مفتوحة' : 'OPEN AREA';
      default:
        return type.toUpperCase();
    }
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
              borderOpacity: (isSelected || _isExpanded) ? 0.4 : 0.05,
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
        Expanded(
          child: AppText(
            text: room.getName(isArabic),
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
        _Spec(icon: Icons.videogame_asset, value: room.controllersCount.toString()),
        _Spec(icon: Icons.tv, value: room.screenSize),
        _Spec(icon: Icons.people, value: room.capacity.toString()),
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
    if (value == '0' || value == 'N/A') return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: AppColors.textSecondary.withOpacity(0.4)),
        SizedBox(width: 4.w),
        AppText(text: value, fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.03))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PriceWidget(price: room.pricePerHourSingle, fontSize: 16.sp, color: themeColor),
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
  }
}

class _BookedOverlay extends StatelessWidget {
  const _BookedOverlay();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.6),
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
  final Color themeColor;

  const _RoomExpandedDetails({
    required this.room,
    required this.isArabic,
    required this.isExpanded,
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
            Divider(color: Colors.white.withOpacity(0.05), height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(title: AppStrings.technicalSetup.tr(), themeColor: themeColor),
                if (room.images.isNotEmpty) _GalleryButton(room: room, themeColor: themeColor),
              ],
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: room.activityNames.map((activity) => _DetailChip(label: activity, themeColor: themeColor)).toList(),
            ),
            if (features.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _SectionHeader(title: AppStrings.roomFeatures.tr(), themeColor: themeColor),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 12.w,
                runSpacing: 6.h,
                children: features.map((f) => _FeatureItem(feature: f)).toList(),
              ),
            ],
          ],
        ),
      ),
      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: RoomConstants.animationDuration,
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
      text: title,
      fontSize: 8.sp,
      fontWeight: FontWeight.bold,
      color: themeColor.withOpacity(0.6),
      letterSpacing: 0.5,
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
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: themeColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 12.sp, color: themeColor),
            SizedBox(width: 4.w),
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: themeColor.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 10.sp, color: themeColor),
          SizedBox(width: 4.w),
          AppText(text: label, fontSize: 10.sp, color: Colors.white60),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.star_border, size: 10.sp, color: AppColors.textSecondary.withOpacity(0.7)),
        SizedBox(width: 4.w),
        AppText(text: feature, fontSize: 10.sp, color: AppColors.textSecondary),
      ],
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'room_constants.dart';
import 'room_expanded_details.dart';
import 'room_main_content.dart';
import 'room_theme_extension.dart';

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

    return BlocListener<LoungeDetailsCubit, LoungeDetailsState>(
      listenWhen: (prev, curr) =>
          (prev.selectedRoomId != widget.room.id &&
              curr.selectedRoomId == widget.room.id),
      listener: (context, state) {
        if (!_isExpanded) {
          setState(() => _isExpanded = true);
        }
      },
      child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (prev, curr) =>
            prev.selectedRoomId != curr.selectedRoomId ||
            prev.bookedRoomIds.contains(widget.room.id) !=
                curr.bookedRoomIds.contains(widget.room.id) ||
            prev.lounge?.isOpen != curr.lounge?.isOpen,
        builder: (context, state) {
          final isSelected = state.selectedRoomId == widget.room.id;
          final isBooked = state.bookedRoomIds.contains(widget.room.id);
          final isLoungeOpen = state.lounge?.isOpen ?? true;
          final isAvailable =
              widget.room.isAvailable && !isBooked && isLoungeOpen;

          return GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedContainer(
              duration: RoomConstants.animationDuration,
              margin: EdgeInsets.only(bottom: 12.h),
              child: GlassContainer(
                borderRadius: RoomConstants.borderRadius,
                borderOpacity: (isSelected || _isExpanded) ? 0.3 : 0.05,
                useBorderColorForGradient: false,
                color: Colors.white.withOpacity(0.02),
                borderColor: isSelected
                    ? themeColor
                    : (widget.room.hasActivePromo
                        ? AppColors.warning.withOpacity(0.4)
                        : (isAvailable
                            ? AppColors.borderDefault
                            : AppColors.danger.withOpacity(0.15))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomMainContent(
                      room: widget.room,
                      isArabic: isArabic,
                      isAvailable: isAvailable,
                      isSelected: isSelected,
                      isExpanded: _isExpanded,
                      themeColor: themeColor,
                    ),
                    RoomExpandedDetails(
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
      ),
    );
  }
}

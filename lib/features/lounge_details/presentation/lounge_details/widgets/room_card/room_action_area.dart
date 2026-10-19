import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../lounge_details_cubit.dart';
import '../../lounge_details_state.dart';
import '../../room_rate_presentation.dart';
import 'room_select_button.dart';

class RoomActionArea extends StatelessWidget {
  final RoomModel room;
  final bool isAvailable;
  final bool isSelected;
  final Color themeColor;

  const RoomActionArea({
    super.key,
    required this.room,
    required this.isAvailable,
    required this.isSelected,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (prev, curr) =>
          prev.roomPlayModes[room.id] != curr.roomPlayModes[room.id] ||
          prev.roomExtraControllers[room.id] !=
              curr.roomExtraControllers[room.id] ||
          prev.lounge != curr.lounge,
      builder: (context, state) {
        final rate = RoomRatePresentation.fromState(room, state);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (rate.hasOffer) ...[
                Text(
                  '${rate.original.toInt()} ${AppStrings.egp.tr()}',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                2.verticalSpace,
              ],
              PriceWidget(
                price: rate.effective,
                fontSize: 16.sp,
                color: rate.hasOffer ? AppColors.success : themeColor,
              ),
              AppText(
                text: AppStrings.perHour.tr().toUpperCase(),
                fontSize: 8.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 8.h),
              RoomSelectButton(
                roomId: room.id,
                selected: isSelected,
                color: themeColor,
              ),
            ],
          ),
        );
      },
    );
  }
}

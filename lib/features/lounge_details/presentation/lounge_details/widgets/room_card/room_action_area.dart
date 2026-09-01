import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'room_constants.dart';

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
              curr.roomExtraControllers[room.id],
      builder: (context, state) {
        final playMode = state.roomPlayModes[room.id] ?? 'single';
        final extraControllers = state.roomExtraControllers[room.id] ?? 0;

        double originalBase = room.pricePerHour;
        if (room.isOpenArea) {
          originalBase =
              playMode == 'single' ? room.pricePerHourSingle : room.pricePerHourMulti;
        }

        double effectiveBase = originalBase;
        if (room.hasActivePromo && room.promoDiscountValue > 0) {
          if (room.promoDiscountType == 'percentage') {
            effectiveBase = originalBase * (1 - (room.promoDiscountValue / 100));
          } else if (room.promoDiscountType == 'fixed') {
            effectiveBase =
                (originalBase - room.promoDiscountValue).clamp(0.0, double.infinity);
          }
        }

        final double finalEffectivePrice =
            effectiveBase + (extraControllers * room.extraControllerPrice);
        final double finalOriginalPrice =
            originalBase + (extraControllers * room.extraControllerPrice);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.white.withOpacity(0.03))),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (room.hasActivePromo) 25.verticalSpace,
              if (room.hasActivePromo) ...[
                Text(
                  "${finalOriginalPrice.toInt()} ${AppStrings.egp.tr()}",
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.5),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                2.verticalSpace,
              ],
              PriceWidget(
                price: finalEffectivePrice,
                fontSize: 16.sp,
                color: room.hasActivePromo ? AppColors.success : themeColor,
              ),
              AppText(
                text: AppStrings.perHour.tr().toUpperCase(),
                fontSize: 7.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: () =>
                    context.read<LoungeDetailsCubit>().toggleRoomSelection(room.id),
                child: AnimatedContainer(
                  duration: RoomConstants.toggleDuration,
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: themeColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
                        : null,
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

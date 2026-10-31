import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../lounge_details_cubit.dart';

class RoomControllerSelector extends StatelessWidget {
  final RoomModel room;
  final int count;
  const RoomControllerSelector({
    super.key,
    required this.room,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.extraControllers.tr(),
              fontSize: 12.sp,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
            AppText(
              text:
                  "+${room.extraControllerPrice.toInt()} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()}",
              fontSize: 9.sp,
              color: AppColors.warning.withValues(alpha: 0.8),
            ),
          ],
        ),
        Row(
          children: [
            _buildStepButton(
              Icons.remove,
              count > 0
                  ? () => context
                        .read<LoungeDetailsCubit>()
                        .updateRoomExtraControllers(room.id, -1)
                  : null,
            ),
            14.horizontalSpace,
            AppText(
              text: count.toString(),
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            14.horizontalSpace,
            _buildStepButton(
              Icons.add,
              count < 4
                  ? () => context
                        .read<LoungeDetailsCubit>()
                        .updateRoomExtraControllers(room.id, 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(6.r),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Icon(icon, size: 14.sp, color: Colors.white),
      ),
    );
  }
}

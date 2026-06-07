import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../data/room_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final isSelected = state.selectedRoomId == room.id;
        final isBooked = state.bookedRoomIds.contains(room.id);
        final isAvailable = room.isAvailable && !isBooked;

        return GestureDetector(
          onTap: isAvailable
              ? () => context.read<LoungeDetailsCubit>().toggleRoomSelection(
            room.id,
          )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.neonBlue
                        : (isAvailable
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.danger.withOpacity(0.3)),
                    width: 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: AppColors.neonBlue.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: room.name,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      text:
                      "${room.controllersCount} ${AppStrings.controllers.tr()} · ${room.screenSize} ${AppStrings.screen.tr()}",
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                    AppText(
                      text: AppStrings.perHour.tr().replaceAll('/', ''),
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "${room.pricePerHour.toInt()}",
                                style: TextStyle(
                                  color: AppColors.neonBlue,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                              TextSpan(
                                text: " ${AppStrings.egp.tr()}",
                                style: TextStyle(
                                  color: AppColors.neonBlue,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -6.h,
                left: 16.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isAvailable
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.danger.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: AppText(
                    text: isAvailable
                        ? AppStrings.available.tr()
                        : AppStrings.booked.tr(),
                    fontSize: 8.sp,
                    color: isAvailable ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.bold,
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
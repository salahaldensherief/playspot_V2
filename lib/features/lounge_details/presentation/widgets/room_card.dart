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
        final isAvailable = room.isAvailable;

        return GestureDetector(
          onTap: isAvailable 
              ? () => context.read<LoungeDetailsCubit>().toggleRoomSelection(room.id)
              : null,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected 
                    ? AppColors.neonBlue 
                    : (isAvailable ? AppColors.borderDefault : AppColors.danger.withOpacity(0.3)),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ] : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      text: room.name,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: AppText(
                        text: isAvailable ? AppStrings.available.tr() : AppStrings.booked.tr(),
                        fontSize: 10.sp,
                        color: isAvailable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                 Spacer(),
                _buildInfoRow(Icons.videogame_asset_outlined, "${room.controllersCount} ${AppStrings.controllers.tr()}"),
                SizedBox(height: 4.h),
                _buildInfoRow(Icons.tv_outlined, "${room.screenSize} ${AppStrings.screen.tr()}"),
              ],
            ),
          ),
        );
      },
    );
  }

  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.neonBlue),
        SizedBox(width: 8.w),
        AppText(text: text, fontSize: 12.sp, color: AppColors.textSecondary),
      ],
    );
  }


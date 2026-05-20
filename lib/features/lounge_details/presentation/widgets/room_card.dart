import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../data/room_model.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: room.isAvailable ? AppColors.borderDefault : AppColors.danger.withOpacity(0.3),
        ),
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
                  color: room.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: AppText(
                  text: room.isAvailable ? "Available" : "Booked",
                  fontSize: 10.sp,
                  color: room.isAvailable ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildInfoRow(Icons.videogame_asset_outlined, "${room.controllersCount} Controllers"),
          SizedBox(height: 4.h),
          _buildInfoRow(Icons.tv_outlined, "${room.screenSize} Screen"),
        ],
      ),
    );
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
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class AvatarPickerWidget extends StatelessWidget {
  final File? avatarFile;
  final VoidCallback onTap;
  final double radius;

  const AvatarPickerWidget({
    super.key,
    required this.avatarFile,
    required this.onTap,
    this.radius = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: radius.r,
            backgroundColor: AppColors.cardBackground,
            backgroundImage: avatarFile != null ? FileImage(avatarFile!) : null,
            child: avatarFile == null
                ? Icon(Icons.person, size: radius.sp, color: AppColors.white)
                : null,
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt,
              color: AppColors.white,
              size: 18.sp,
            ),
          ),
        ],
      ),
    );
  }
}
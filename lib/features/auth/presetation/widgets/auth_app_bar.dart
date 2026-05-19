import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthAppBar extends StatelessWidget {
  const AuthAppBar({super.key, this.title, this.subTitle});
  final String? title;
  final String? subTitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -70.h,
            left: 150.w,
            right: 0,
            child: Center(
              child: Container(
                width: 350.w,
                height: 300.h,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00D9FF),
                      blurRadius: 100.r,
                      spreadRadius: 30.r,
                    ),
                    BoxShadow(
                      color: Color(0xFFA855F7),
                      blurRadius: 100.r,
                      spreadRadius: 30.r,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -180.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Create an Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                  ),
                    ),
                if (subTitle != null) ...[
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      subTitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

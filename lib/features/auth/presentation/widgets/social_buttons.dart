import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/assets_manager.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/svg_icon/svg_icon_widget.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class SocialButtons extends StatelessWidget {
  final void Function()? googleOnTap;
  final void Function()? facebookOnTap;
  final void Function()? appleOnTap;

  const SocialButtons({
    super.key,
    this.googleOnTap,
    this.appleOnTap,
    this.facebookOnTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:  EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          _space(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _socialMediaContainer(
                  image: AssetsManager.google,
                  onTap: googleOnTap,
                ),
              ),
              SizedBox(width: 6.0.w),
              Expanded(
                child: _socialMediaContainer(
                  image: AssetsManager.facebook,
                  onTap: facebookOnTap,
                ),
              ),
              if (Platform.isIOS) ...[
                SizedBox(width: 6.0.w),
                Expanded(
                  child: _socialMediaContainer(
                    image: AssetsManager.appleDark,
                    onTap: appleOnTap,
                  ),
                ),
              ],
            ],
          ),        _space(),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.5,
                  decoration: BoxDecoration(
                    color: AppColors.transparent,
                    border: Border.all(

                      color: AppColors.borderDefault,
                      width: 0.5,

                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.0.w),
              AppText(
                text: AppStrings.or.tr(),
                color: AppColors.textSecondary,
                fontSize: 12.0.sp,
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Container(
                  height: 0.5,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.borderDefault,
                      width: 0.5.w,
                    ),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _space({double? height}) {
    return SizedBox(height: height ?? 20.0);
  }

  Widget _socialMediaContainer({String? image, void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        height: 50.0.h,
        decoration: BoxDecoration(
          color: AppColors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: AppColors.borderDefault,
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SvgIconWidget(
            path: image ?? "",
            height: 20.h,
            width: 20.w,
            matchTextDirection: false,
          ),
        ),
      ),
    );
  }}
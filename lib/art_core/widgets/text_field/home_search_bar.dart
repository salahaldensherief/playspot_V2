import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';

class HomeSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final String? hint;
  final bool readOnly;
  final VoidCallback? onTap;

  const HomeSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.hint,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      hint: hint ?? "search".tr(),
      // hintIcon: AssetsManager.search,
      borderRadius: 25.r,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';

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
      hint: hint ?? "Search lounges near you...",
      // hintIcon: AssetsManager.search,
      borderRadius: 25.r,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
    );
  }
}

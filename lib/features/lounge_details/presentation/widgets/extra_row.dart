import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../data/models/extra_model.dart';
import 'quantity_selector.dart';

class ExtraRow extends StatelessWidget {
  final ExtraModel extra;
  const ExtraRow({super.key, required this.extra});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(text: extra.name, fontSize: 14.sp, color: AppColors.white, fontWeight: FontWeight.bold),
                AppText(text: "${extra.price.toInt()} ${AppStrings.egp.tr()}", fontSize: 12.sp, color: AppColors.neonPurple),
              ],
            ),
          ),
          QuantitySelector(extraId: extra.id),
        ],
      ),
    );
  }
}

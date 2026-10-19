import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../../lounge_details/data/models/extra_model.dart';
import '../../../domain/entities/out_of_stock_item.dart';
import 'canteen_extra_card.dart';

class CanteenExtrasSection extends StatelessWidget {
  final List<ExtraModel> extras;
  final List<OutOfStockItem> unavailable;
  final bool isArabic;
  final int Function(String id) getQty;
  final OutOfStockItem? Function(List<OutOfStockItem> unavail, String id)
  findUnavailable;
  final void Function(ExtraModel item) onAdd;
  final void Function(ExtraModel item) onRemove;

  const CanteenExtrasSection({
    super.key,
    required this.extras,
    required this.unavailable,
    required this.isArabic,
    required this.getQty,
    required this.findUnavailable,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.fastfood_rounded,
              color: AppColors.neonBlue,
              size: 19.sp,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: AppText(
                text: AppStrings.singleItems.tr(),
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ...extras.map((item) {
          final qty = getQty(item.id);
          final unavail = findUnavailable(unavailable, item.id);
          return CanteenExtraCard(
            item: item,
            qty: qty,
            unavailableItem: unavail,
            isArabic: isArabic,
            onAdd: () => onAdd(item),
            onRemove: () => onRemove(item),
          );
        }),
        SizedBox(height: 14.h),
      ],
    );
  }
}

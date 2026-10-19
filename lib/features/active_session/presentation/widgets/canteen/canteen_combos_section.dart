import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../domain/entities/canteen_combo.dart';
import '../../../domain/entities/out_of_stock_item.dart';
import 'canteen_combo_card.dart';

class CanteenCombosSection extends StatelessWidget {
  final List<CanteenCombo> combos;
  final List<OutOfStockItem> unavailable;
  final bool isArabic;
  final int Function(String id) getQty;
  final OutOfStockItem? Function(
    List<OutOfStockItem> unavail,
    CanteenCombo combo,
  )
  findUnavailable;
  final void Function(CanteenCombo combo) onAdd;
  final void Function(CanteenCombo combo) onRemove;

  const CanteenCombosSection({
    super.key,
    required this.combos,
    required this.unavailable,
    required this.isArabic,
    required this.getQty,
    required this.findUnavailable,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (combos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.warning,
              size: 19.sp,
            ),
            SizedBox(width: 6.w),
            AppText(
              text: AppStrings.combosAndOffers.tr(),
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ...combos.map((combo) {
          final qty = getQty(combo.id);
          final unavail = findUnavailable(unavailable, combo);
          return CanteenComboCard(
            combo: combo,
            qty: qty,
            unavailableItem: unavail,
            isArabic: isArabic,
            onAdd: () => onAdd(combo),
            onRemove: () => onRemove(combo),
          );
        }),
        SizedBox(height: 16.h),
      ],
    );
  }
}

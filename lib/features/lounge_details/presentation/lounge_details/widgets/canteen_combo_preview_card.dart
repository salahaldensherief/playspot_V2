import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:playspot/features/active_session/domain/entities/canteen_combo.dart';

class CanteenComboPreviewCard extends StatelessWidget {
  final CanteenCombo combo;

  const CanteenComboPreviewCard({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final name = combo.getName(isArabic);
    final description = combo.getDescription(isArabic);
    final components = combo.items
        .map((item) => '${item.quantity}× ${item.getName(isArabic)}')
        .join(' + ');
    final imageUrl = combo.imageUrl;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            AppImage(
              urlImg: imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              borderRadius: 10,
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.fastfood_rounded,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (components.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    components,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${combo.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                      style: const TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (combo.separateItemsPrice > combo.price)
                      Text(
                        '${combo.separateItemsPrice.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (combo.savings > 0)
                      Text(
                        AppStrings.saveAmount.tr(
                          args: [
                            '${combo.savings.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                          ],
                        ),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

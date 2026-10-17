import 'package:playspot/art_core/app_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/images/app_images.dart';
import '../../../data/models/extra_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class CanteenMenuItem extends StatelessWidget {
  const CanteenMenuItem({super.key, required this.extra});
  final ExtraModel extra;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
    buildWhen: (a, b) =>
        a.selectedExtras[extra.id] != b.selectedExtras[extra.id],
    builder: (context, state) {
      final qty = state.selectedExtras[extra.id] ?? 0;
      final name = context.locale.languageCode == 'ar'
          ? extra.nameAr
          : extra.nameEn;
      final fallbackImage = Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.mutedBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          extra.category == 'drinks'
              ? Icons.local_drink_outlined
              : Icons.restaurant_outlined,
          color: AppColors.textSecondary,
        ),
      );
      final details = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (extra.imageUrl case final imageUrl?)
            AppImage(
              urlImg: imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              borderRadius: 12,
              errorWidget: fallbackImage,
            )
          else
            fallbackImage,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${extra.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!extra.isAvailable)
                  Text(
                    AppStrings.canteenItemUnavailable.tr(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
      final selector = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: AppStrings.canteenRemoveItem.tr(),
            onPressed: qty > 0
                ? () => context.read<LoungeDetailsCubit>().updateExtraQuantity(
                    extra.id,
                    -1,
                  )
                : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.textSecondary,
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: AppStrings.canteenAddItem.tr(),
            onPressed: extra.isAvailable && qty < 99
                ? () => context.read<LoungeDetailsCubit>().updateExtraQuantity(
                    extra.id,
                    1,
                  )
                : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (qty > 0 ? AppColors.primary : AppColors.textSecondary)
                .withValues(alpha: .25),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: selector,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 8),
                selector,
              ],
            );
          },
        ),
      );
    },
  );
}

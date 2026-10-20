import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/art_core/widgets/canteen/canteen_category_bar.dart';

import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

/// True adds the selected items, false continues without them, null cancels.
class BookingCanteenOfferDialog extends StatefulWidget {
  const BookingCanteenOfferDialog({super.key});

  @override
  State<BookingCanteenOfferDialog> createState() =>
      _BookingCanteenOfferDialogState();
}

class _BookingCanteenOfferDialogState extends State<BookingCanteenOfferDialog> {
  String selectedCategory = 'all';

  @override
  Widget build(BuildContext context) => Container(
    height: math.min(MediaQuery.sizeOf(context).height * .88, 720),
    constraints: const BoxConstraints(maxWidth: 600),
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      color: AppColors.scaffoldBackground,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (a, b) =>
          a.extras != b.extras || a.selectedExtras != b.selectedExtras,
      builder: (context, state) {
        final items = state.extras.where((item) => item.isAvailable).toList();
        final categories = items.map((item) => item.category).toSet();
        final visibleItems = selectedCategory == 'all'
            ? items
            : items.where((item) => item.category == selectedCategory).toList();
        final count = items.fold<int>(
          0,
          (sum, item) => sum + (state.selectedExtras[item.id] ?? 0),
        );
        final total = items.fold<double>(
          0,
          (sum, item) =>
              sum + item.price * (state.selectedExtras[item.id] ?? 0),
        );
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 10),
            const _OfferHeader(),
            if (categories.length > 1) ...[
              const SizedBox(height: 14),
              CanteenCategoryBar(
                selectedCategory: selectedCategory,
                hasCombos: false,
                categories: categories,
                onSelectCategory: (value) =>
                    setState(() => selectedCategory = value),
              ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      text: AppStrings.bookingCanteenOfferSection.tr(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppText(
                    text: AppStrings.canteenItemCount.tr(
                      namedArgs: {'count': '${items.length}'},
                    ),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                itemCount: visibleItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _OfferItem(
                  item: visibleItems[index],
                  quantity: state.selectedExtras[visibleItems[index].id] ?? 0,
                ),
              ),
            ),
            _OfferFooter(count: count, total: total),
          ],
        );
      },
    ),
  );
}

class _OfferHeader extends StatelessWidget {
  const _OfferHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 10, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [Color(0xFF173748), Color(0xFF201B3C)],
      ),
      border: Border.all(color: AppColors.neonBlue.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.neonBlue,
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                text: AppStrings.bookingCanteenOfferEyebrow.tr(),
                style: const TextStyle(
                  color: AppColors.neonBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: AppStrings.close.tr(),
              onPressed: () => Navigator.of(context).pop(),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        AppText(
          text: AppStrings.bookingCanteenOfferTitle.tr(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          text: AppStrings.bookingCanteenOfferSubtitle.tr(),
          style: const TextStyle(
            color: Color(0xFFD0D4DF),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

class _OfferItem extends StatelessWidget {
  const _OfferItem({required this.item, required this.quantity});

  final ExtraModel item;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final name = context.locale.languageCode == 'ar'
        ? item.nameAr
        : item.nameEn;
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.mutedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        item.category == 'drinks'
            ? Icons.local_drink_outlined
            : Icons.restaurant_outlined,
        color: AppColors.neonBlue,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: quantity > 0
              ? AppColors.neonBlue.withValues(alpha: .65)
              : AppColors.borderDefault,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            children: [
              if (item.imageUrl case final imageUrl?)
                AppImage(
                  urlImg: imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  borderRadius: 12,
                  errorWidget: fallback,
                )
              else
                fallback,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AppText(
                      text:
                          '${item.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                      style: const TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final selector = _QuantityControl(item: item, quantity: quantity);
          if (constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(14) > 19) {
            return Column(
              children: [
                details,
                const SizedBox(height: 8),
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
              selector,
            ],
          );
        },
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.item, required this.quantity});

  final ExtraModel item;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoungeDetailsCubit>();
    if (quantity == 0) {
      return OutlinedButton.icon(
        onPressed: () => cubit.updateExtraQuantity(item.id, 1),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: AppText(text: AppStrings.bookingCanteenOfferAddItem.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neonBlue,
          side: BorderSide(color: AppColors.neonBlue.withValues(alpha: .5)),
          minimumSize: const Size(84, 48),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: AppStrings.canteenRemoveItem.tr(),
            onPressed: () => cubit.updateExtraQuantity(item.id, -1),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.remove_rounded, color: AppColors.neonBlue),
          ),
          AppText(
            text: '$quantity',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: AppStrings.canteenAddItem.tr(),
            onPressed: quantity < 99
                ? () => cubit.updateExtraQuantity(item.id, 1)
                : null,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.add_rounded, color: AppColors.neonBlue),
          ),
        ],
      ),
    );
  }
}

class _OfferFooter extends StatelessWidget {
  const _OfferFooter({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsetsDirectional.fromSTEB(
      20,
      12,
      20,
      math.max(MediaQuery.viewPaddingOf(context).bottom, 12),
    ),
    decoration: BoxDecoration(
      color: AppColors.scaffoldBackground,
      border: Border(top: BorderSide(color: AppColors.borderDefault)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                text: count == 0
                    ? AppStrings.bookingCanteenOfferNothingSelected.tr()
                    : AppStrings.canteenSelectedCount.tr(
                        namedArgs: {'count': '$count'},
                      ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (count > 0)
              AppText(
                text:
                    '${total.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppText(
            text: AppStrings.bookingCanteenOfferPriceNote.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: count > 0 ? () => Navigator.of(context).pop(true) : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.neonBlue,
              foregroundColor: AppColors.buttonPrimaryText,
              disabledBackgroundColor: AppColors.mutedBackground,
              disabledForegroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: AppText(text: AppStrings.bookingCanteenOfferAdd.tr()),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: AppText(text: AppStrings.bookingCanteenOfferNoThanks.tr()),
          ),
        ),
      ],
    ),
  );
}

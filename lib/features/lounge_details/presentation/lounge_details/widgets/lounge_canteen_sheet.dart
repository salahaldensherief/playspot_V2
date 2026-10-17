import 'package:playspot/art_core/app_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'canteen_menu_item.dart';
import 'canteen_combo_preview_card.dart';
import 'canteen_filter_chip.dart';

class LoungeCanteenSheet extends StatefulWidget {
  const LoungeCanteenSheet({super.key});
  @override
  State<LoungeCanteenSheet> createState() => _LoungeCanteenSheetState();
}

class _LoungeCanteenSheetState extends State<LoungeCanteenSheet> {
  String? _category;
  bool _offers = false;
  String _categoryName(String value) => switch (value) {
    'drinks' => AppStrings.drinks.tr(),
    'food' => AppStrings.food.tr(),
    'snacks' => AppStrings.snacks.tr(),
    'desserts' => AppStrings.desserts.tr(),
    _ => AppStrings.canteenOtherCategory.tr(),
  };
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .85,
    minChildSize: .5,
    maxChildSize: .96,
    expand: false,
    builder: (context, controller) =>
        BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          buildWhen: (a, b) =>
              a.extras != b.extras ||
              a.combos != b.combos ||
              a.selectedExtras != b.selectedExtras ||
              a.status != b.status,
          builder: (context, state) {
            final combos = state.combos
                .where((combo) => combo.isAvailable)
                .toList();
            final categories = state.extras
                .map((e) => e.category)
                .toSet()
                .toList();
            final items = state.extras
                .where((e) => _category == null || e.category == _category)
                .toList();
            final count = state.selectedExtras.values.fold<int>(
              0,
              (a, b) => a + b,
            );
            final total = state.extras.fold<double>(
              0,
              (sum, e) => sum + e.price * (state.selectedExtras[e.id] ?? 0),
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.canteenMenuTitle.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppStrings.close.tr(),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CanteenFilterChip(
                          label: AppStrings.canteenIndividualItems.tr(),
                          selected: !_offers,
                          onSelected: () => setState(() => _offers = false),
                        ),
                        CanteenFilterChip(
                          label: AppStrings.canteenComboOffers.tr(),
                          selected: _offers,
                          onSelected: () => setState(() => _offers = true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CustomScrollView(
                    controller: controller,
                    slivers: [
                      if (_offers) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              AppStrings.canteenComboPreviewHint.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (combos.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList.builder(
                              itemCount: combos.length,
                              itemBuilder: (_, index) =>
                                  CanteenComboPreviewCard(combo: combos[index]),
                            ),
                          )
                        else
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                AppStrings.canteenNoOffers.tr(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ] else ...[
                        SliverToBoxAdapter(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: CanteenFilterChip(
                                    label: AppStrings.all.tr(),
                                    selected: _category == null,
                                    onSelected: () =>
                                        setState(() => _category = null),
                                  ),
                                ),
                                for (final category in categories)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: CanteenFilterChip(
                                      label: _categoryName(category),
                                      selected: _category == category,
                                      onSelected: () =>
                                          setState(() => _category = category),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (items.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                AppStrings.canteenMenuEmpty.tr(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                            itemCount: items.length,
                            itemBuilder: (_, index) =>
                                CanteenMenuItem(extra: items[index]),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: .15),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text(
                                  AppStrings.canteenSelectedCount.tr(
                                    namedArgs: {'count': '$count'},
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${total.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.buttonPrimaryText,
                          ),
                          child: Text(AppStrings.done.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
  );
}

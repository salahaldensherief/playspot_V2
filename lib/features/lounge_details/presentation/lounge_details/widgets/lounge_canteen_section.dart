import 'package:playspot/art_core/app_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'lounge_canteen_sheet.dart';

class LoungeCanteenSection extends StatelessWidget {
  const LoungeCanteenSection({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
    buildWhen: (a, b) =>
        a.extras != b.extras ||
        a.combos != b.combos ||
        a.selectedExtras != b.selectedExtras ||
        a.status != b.status,
    builder: (context, state) {
      final loading = state.status == LoungeDetailsStatus.loading;
      final offers = state.combos.where((c) => c.isAvailable).length;
      final available = state.extras.isNotEmpty || offers > 0;
      final selected = state.selectedExtras.values.fold<int>(
        0,
        (a, b) => a + b,
      );
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Material(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withValues(alpha: .25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.canteenMenuTitle.tr(),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.canteenMenuSubtitle.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const LinearProgressIndicator()
                  else if (available)
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          AppStrings.canteenItemCount.tr(
                            namedArgs: {'count': '${state.extras.length}'},
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (offers > 0)
                          Text(
                            AppStrings.canteenOfferCount.tr(
                              namedArgs: {'count': '$offers'},
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (selected > 0)
                          Text(
                            AppStrings.canteenSelectedCount.tr(
                              namedArgs: {'count': '$selected'},
                            ),
                            style: const TextStyle(color: AppColors.primary),
                          ),
                      ],
                    )
                  else
                    Text(
                      AppStrings.canteenMenuEmpty.tr(),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: 12),
                  if (state.status == LoungeDetailsStatus.error) ...[
                    Text(
                      AppStrings.canteenRefreshError.tr(),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (state.lounge case final lounge?)
                      TextButton.icon(
                        onPressed: () => context
                            .read<LoungeDetailsCubit>()
                            .getLoungeDetails(lounge.id),
                        icon: const Icon(Icons.refresh),
                        label: Text(AppStrings.retry.tr()),
                      ),
                  ],
                  FilledButton.icon(
                    onPressed: available
                        ? () {
                            final cubit = context.read<LoungeDetailsCubit>();
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              showDragHandle: true,
                              constraints: const BoxConstraints(maxWidth: 640),
                              backgroundColor: AppColors.scaffoldBackground,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (_) => BlocProvider.value(
                                value: cubit,
                                child: const LoungeCanteenSheet(),
                              ),
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.buttonPrimaryText,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(AppStrings.canteenBrowseMenu.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

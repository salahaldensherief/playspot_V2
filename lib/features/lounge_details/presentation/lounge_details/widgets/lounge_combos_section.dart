import 'canteen_combo_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';

import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

/// Read-only offer preview. Canteen ordering still happens through the live
/// session flow, where the backend checks stock, timing, and the final price.
class LoungeCombosSection extends StatelessWidget {
  const LoungeCombosSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) => previous.combos != current.combos,
      builder: (context, state) {
        final combos = state.combos
            .where((combo) => combo.isAvailable)
            .toList();
        if (combos.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            const SliverSectionHeader(
              title: AppStrings.combosAndOffers,
              compact: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final combo in combos)
                      CanteenComboPreviewCard(combo: combo),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

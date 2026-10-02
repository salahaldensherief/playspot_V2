import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';

class LoungeTournamentBanner extends StatelessWidget {
  final TournamentEntity tournament;
  const LoungeTournamentBanner({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tournament.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${tournament.game} · ${tournament.entryFee} ${AppStrings.egp.tr()}',
          ),
          const SizedBox(height: 8),
          AppButton(
            content: ButtonContent(label: AppStrings.cardDetails.tr()),
            behavior: ButtonBehavior.tap(
              onTap: () => context.pushNamed(
                RouterKeys.tournamentDetails,
                pathParameters: {'id': tournament.id},
              ),
            ),
            buttonConfig: ButtonConfig.outlined(
              height: 48 * MediaQuery.textScalerOf(context).scale(1),
              textStyle: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

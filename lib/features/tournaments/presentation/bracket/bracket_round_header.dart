// bracket_round_header.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';

class BracketRoundHeader extends StatelessWidget {
  final int roundsFromFinal; // 0 = النهائي، 1 = نص النهائي...
  final int matchCountInRound;

  const BracketRoundHeader({
    super.key,
    required this.roundsFromFinal,
    required this.matchCountInRound,
  });

  String _label() {
    if (roundsFromFinal == 0) {
      return AppStrings.tournamentFinal.tr();
    }

    if (roundsFromFinal == 1) {
      return AppStrings.tournamentSemiFinal.tr();
    }

    if (roundsFromFinal == 2) {
      return AppStrings.tournamentQuarterFinal.tr();
    }

    return AppStrings.roundOf.tr(
      args: ['$matchCountInRound'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFinal = roundsFromFinal == 0;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: isFinal
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.mutedBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFinal
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.neonBlue.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        _label(),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isFinal ? AppColors.warning : AppColors.neonBlue,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          fontFamily: 'Orbitron',
        ),
      ),
    );
  }
}

class BracketEmptyState extends StatelessWidget {
  const BracketEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.account_tree_outlined,
          size: 56,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.tournamentBracket.tr(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

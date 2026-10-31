import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class LoungeDetailPanel extends StatelessWidget {
  final String titleKey;
  final IconData icon;
  final Widget child;
  final bool collapsible;

  const LoungeDetailPanel({
    super.key,
    required this.titleKey,
    required this.icon,
    required this.child,
    this.collapsible = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: collapsible ? EdgeInsets.zero : const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
        child: collapsible
            ? _buildCollapsible(context, titleStyle)
            : _buildExpanded(titleStyle),
      ),
    );
  }

  Widget _buildCollapsible(BuildContext context, TextStyle? titleStyle) =>
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            iconColor: AppColors.neonBlue,
            collapsedIconColor: AppColors.textSecondary,
            leading: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.neonBlue10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.neonBlue),
            ),
            title: AppText(text: titleKey.tr(), style: titleStyle),
            children: [child],
          ),
        ),
      );

  Widget _buildExpanded(TextStyle? titleStyle) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: AppColors.neonBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(text: titleKey.tr(), style: titleStyle),
          ),
        ],
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

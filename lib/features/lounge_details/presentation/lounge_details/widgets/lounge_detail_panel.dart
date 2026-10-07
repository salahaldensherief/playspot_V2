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
  Widget build(BuildContext context) => Container(
    padding: collapsible ? EdgeInsets.zero : const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF13131E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Tajawal',
        fontSize: 13,
        height: 1.4,
      ),
      child: collapsible
          ? Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                iconColor: AppColors.neonBlue,
                collapsedIconColor: Colors.white70,
                leading: Icon(icon, size: 18, color: AppColors.neonBlue),
                title: Text(titleKey.tr(), style: const TextStyle(
                  color: Colors.white, fontFamily: 'Tajawal', fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
                children: [child],
              ),
            )
          : Column(
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
                child: Text(
                  titleKey.tr(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

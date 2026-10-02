import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import '../buttons/app_button.dart';
import '../buttons/res/button_behavior.dart';
import '../buttons/res/button_content.dart';
import '../buttons/res/button_style_config.dart';
import '../text/app_text.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllTap;
  final String? seeAllText;
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAllTap,
    this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              text: title.tr(),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          if (onSeeAllTap != null) ...[
            const SizedBox(width: 8),
            AppButton(
              content: ButtonContent(
                label: (seeAllText ?? AppStrings.seeAll).tr(),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.neonBlue,
                ),
              ),
              behavior: ButtonBehavior.tap(onTap: onSeeAllTap),
              buttonConfig: ButtonConfig(
                width: 112,
                height: 48 * MediaQuery.textScalerOf(context).scale(1),
                textStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.neonBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

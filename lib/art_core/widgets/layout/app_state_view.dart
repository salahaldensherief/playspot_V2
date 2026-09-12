import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../buttons/app_button.dart';
import '../buttons/res/button_behavior.dart';
import '../buttons/res/button_content.dart';
import '../buttons/res/button_style_config.dart';
import '../text/app_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';


enum AppStateViewType { error, empty }

class AppStateView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppStateViewType type;
  final VoidCallback? onRetry;

  const AppStateView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.type = AppStateViewType.empty,
    this.onRetry,
  });

  factory AppStateView.error({
    String title = "somethingWentWrong",
    String? subtitle,
    VoidCallback? onRetry,
  }) =>
      AppStateView(
        title: title,
        subtitle: subtitle,
        icon: Icons.error_outline_rounded,
        type: AppStateViewType.error,
        onRetry: onRetry,
      );

  factory AppStateView.empty({
    required String title,
    String? subtitle,
    IconData icon = Icons.hourglass_empty_rounded,
  }) =>
      AppStateView(
        title: title,
        subtitle: subtitle,
        icon: icon,
        type: AppStateViewType.empty,
      );

  String _safeTranslate(String text) {
    if (text.isEmpty) return text;
    if (text.contains(' ') || text.contains('\n')) {
      return text;
    }
    return text.tr();
  }


  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.w24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? (type == AppStateViewType.error ? Icons.error_outline : Icons.inbox_outlined),
              size: 64.sp,
              color: type == AppStateViewType.error ? AppColors.danger : AppColors.textSecondary,
            ),
            SizedBox(height: AppSizes.s16),
            AppText(
              text: _safeTranslate(title),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: AppSizes.s8),
              AppText(
                text: _safeTranslate(subtitle!),
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: AppSizes.s24),
              AppButton(
                content: ButtonContent(label: AppStrings.retry.tr()),
                behavior: ButtonBehavior.tap(onTap: onRetry),
                buttonConfig: ButtonConfig(
                  height: 44.h,
                  width: 120.w,
                  backgroundColor: AppColors.neonBlue,
                  borderRadius: AppSizes.r12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SliverAppStateView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppStateViewType type;
  final VoidCallback? onRetry;
  final bool fillRemaining;

  const SliverAppStateView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.type = AppStateViewType.empty,
    this.onRetry,
    this.fillRemaining = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = AppStateView(
      title: title,
      subtitle: subtitle,
      icon: icon,
      type: type,
      onRetry: onRetry,
    );
    
    return fillRemaining
        ? SliverFillRemaining(hasScrollBody: false, child: child)
        : SliverToBoxAdapter(child: child);
  }
}

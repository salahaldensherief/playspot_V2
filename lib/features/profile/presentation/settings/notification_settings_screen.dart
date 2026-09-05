import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'notification_settings_cubit.dart';
import 'notification_settings_state.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -0.8),
            radius: 1.5,
            colors: [
              AppColors.neonBlue10,
              AppColors.scaffoldBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
                  buildWhen: (previous, current) =>
                      previous.pushNotificationsEnabled != current.pushNotificationsEnabled ||
                      previous.bookingUpdates != current.bookingUpdates ||
                      previous.offersPromotions != current.offersPromotions ||
                      previous.systemStatus != current.systemStatus ||
                      previous.tournamentsAndEvents != current.tournamentsAndEvents ||
                      previous.status != current.status,
                  builder: (context, state) {
                    return ListView(
                      padding: 20.allPadding,
                      children: [
                        _buildSettingsGroup(
                          context: context,
                          title: AppStrings.general.tr(),
                          children: [
                            _buildActionTile(
                              icon: TablerIcons.world,
                              title: AppStrings.language.tr(),
                              subtitle: context.locale.languageCode == 'ar' ? 'العربية' : 'English',
                              onTap: () => _showLanguagePicker(context),
                            ),
                            _buildActionTile(
                              icon: TablerIcons.credit_card,
                              title: AppStrings.paymentMethods.tr(),
                              showBorder: true,
                              onTap: () => _showComingSoon(context),
                            ),
                          ],
                        ),
                        24.verticalSpace,
                        _buildSettingsGroup(
                          context: context,
                          title: AppStrings.notifications.tr(),
                          children: [
                            _buildSettingTile(
                              icon: TablerIcons.bell,
                              title: AppStrings.pushNotifications.tr(),
                              subtitle: AppStrings.pushNotificationsDesc.tr(),
                              value: state.pushNotificationsEnabled,
                              onChanged: (val) => context
                                  .read<NotificationSettingsCubit>()
                                  .togglePreference('push', val),
                            ),
                          ],
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 400),
                          opacity: state.pushNotificationsEnabled ? 1.0 : 0.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: state.pushNotificationsEnabled ? null : 0,
                            curve: Curves.easeInOut,
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  24.verticalSpace,
                                  _buildSettingsGroup(
                                    context: context,
                                    title: AppStrings.categories.tr(),
                                    children: [
                                      _buildSettingTile(
                                        icon: TablerIcons.calendar_check,
                                        title: AppStrings.bookingUpdates.tr(),
                                        subtitle: AppStrings.bookingUpdatesDesc.tr(),
                                        value: state.bookingUpdates,
                                        onChanged: (val) => context
                                            .read<NotificationSettingsCubit>()
                                            .togglePreference('booking', val),
                                        isEnabled: state.pushNotificationsEnabled,
                                      ),
                                      _buildSettingTile(
                                        icon: TablerIcons.discount_2,
                                        title: AppStrings.offersPromotions.tr(),
                                        subtitle: AppStrings.offersPromotionsDesc.tr(),
                                        value: state.offersPromotions,
                                        onChanged: (val) => context
                                            .read<NotificationSettingsCubit>()
                                            .togglePreference('offers', val),
                                        showBorder: true,
                                        isEnabled: state.pushNotificationsEnabled,
                                      ),
                                      _buildSettingTile(
                                        icon: TablerIcons.trophy,
                                        title: AppStrings.tournamentsAndEvents.tr(),
                                        subtitle: AppStrings.tournamentsAndEventsDesc.tr(),
                                        value: state.tournamentsAndEvents,
                                        onChanged: (val) => context
                                            .read<NotificationSettingsCubit>()
                                            .togglePreference('tournaments', val),
                                        showBorder: true,
                                        isEnabled: state.pushNotificationsEnabled,
                                      ),
                                      _buildSettingTile(
                                        icon: TablerIcons.info_circle,
                                        title: AppStrings.systemNotifications.tr(),
                                        subtitle: AppStrings.systemNotificationsDesc.tr(),
                                        value: state.systemStatus,
                                        onChanged: (val) => context
                                            .read<NotificationSettingsCubit>()
                                            .togglePreference('system', val),
                                        showBorder: true,
                                        isEnabled: state.pushNotificationsEnabled,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: 16.horizontalPadding + 20.verticalPadding,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(TablerIcons.chevron_left, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.whiteOverlay,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.r12)),
            ),
          ),
          16.horizontalSpace,
          AppText(
            text: AppStrings.settings.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required BuildContext context, required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: 8.horizontalPadding + 12.verticalPadding,
          child: AppText(
            text: title.toUpperCase(),
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.neonBlue,
            letterSpacing: 1.2,
          ),
        ),
        GlassContainer(
          borderRadius: AppSizes.r24,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showBorder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showBorder ? const Border(top: BorderSide(color: AppColors.borderDefault)) : null,
        ),
        padding: 20.horizontalPadding + 16.verticalPadding,
        child: Row(
          children: [
            Container(
              padding: 10.allPadding,
              decoration: BoxDecoration(
                color: AppColors.whiteOverlay,
                borderRadius: BorderRadius.circular(AppSizes.r12),
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            16.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: title,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  if (subtitle != null) ...[
                    2.verticalSpace,
                    AppText(
                      text: subtitle,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
            Icon(TablerIcons.chevron_right, color: AppColors.textSecondary, size: 18.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showBorder = false,
    bool isEnabled = true,
  }) {
    return IgnorePointer(
      ignoring: !isEnabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isEnabled ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            border: showBorder ? const Border(top: BorderSide(color: AppColors.borderDefault)) : null,
          ),
          padding: 20.horizontalPadding + 16.verticalPadding,
          child: Row(
            children: [
              Container(
                padding: 10.allPadding,
                decoration: BoxDecoration(
                  color: AppColors.whiteOverlay,
                  borderRadius: BorderRadius.circular(AppSizes.r12),
                ),
                child: Icon(icon, color: Colors.white, size: 20.sp),
              ),
              16.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: title,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    2.verticalSpace,
                    AppText(
                      text: subtitle,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isEnabled ? value : false,
                onChanged: isEnabled ? onChanged : null,
                activeThumbColor: AppColors.neonBlue,
                activeTrackColor: AppColors.neonBlue20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (bottomSheetContext) => Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              text: AppStrings.language.tr(),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 24.h),
            _buildLanguageOption(
              context,
              title: 'English',
              isSelected: context.locale.languageCode == 'en',
              onTap: () {
                context.read<LocaleCubit>().setLocale(context, 'en');
                Navigator.pop(bottomSheetContext);
              },
            ),
            SizedBox(height: 12.h),
            _buildLanguageOption(
              context,
              title: 'العربية',
              isSelected: context.locale.languageCode == 'ar',
              onTap: () {
                context.read<LocaleCubit>().setLocale(context, 'ar');
                Navigator.pop(bottomSheetContext);
              },
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
          ),
        ),
        child: Row(
          children: [
            AppText(
              text: title,
              fontSize: 16.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.neonBlue : Colors.white,
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.neonBlue, size: 20.sp),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    GameHudToast.show(
      context,
      AppStrings.comingSoon.tr(),
      type: ToastType.info,
    );
  }
}

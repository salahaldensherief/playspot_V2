import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'notification_settings_cubit.dart';
import 'notification_settings_state.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.8, -0.8),
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
                  builder: (context, state) {
                    return ListView(
                      padding: 20.allPadding,
                      children: [
                        _buildSettingsGroup(
                          context: context,
                          title: AppStrings.general.tr(),
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
            text: AppStrings.notificationSettings.tr(),
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
                activeColor: AppColors.neonBlue,
                activeTrackColor: AppColors.neonBlue20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

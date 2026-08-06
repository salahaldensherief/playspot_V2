import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import '../data/models/notification_model.dart';
import 'cubit/notifications_cubit.dart';
import 'cubit/notifications_state.dart';
import 'widgets/notification_item.dart';
import 'widgets/qr_location_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final lang = context.locale.languageCode;
        context.read<NotificationsCubit>().getNotifications(lang);
      }
    });
  }

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
              AppColors.neonBlue.withValues(alpha: 0.05),
              AppColors.scaffoldBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: BlocBuilder<NotificationsCubit, NotificationsState>(
                  builder: (context, state) {
                    if (state.status == NotificationsStatus.loading) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.neonBlue),
                      );
                    }

                    if (state.notifications.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: 16.allPadding,
                      itemCount: state.notifications.length + 1,
                      itemBuilder: (context, index) {
                        if (index == state.notifications.length) {
                          return const SafeBottomSpacer();
                        }
                        final notification = state.notifications[index];
                        return NotificationItem(
                          notification: notification,
                          onTap: () => context.read<NotificationsCubit>().markAsRead(notification.id),
                        );
                      },
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(TablerIcons.chevron_left, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          AppText(
            text: AppStrings.notifications.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: "Orbitron",
          ),
          IconButton(
            onPressed: () => context.read<NotificationsCubit>().markAllAsRead(),
            icon: const Icon(TablerIcons.checks, color: AppColors.neonBlue),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.neonBlue.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              TablerIcons.bell_off,
              size: 64.sp,
              color: AppColors.neonBlue.withOpacity(0.2),
            ),
          ),
          SizedBox(height: 24.h),
          AppText(
            text: AppStrings.noNotificationsYet.tr(),
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          SizedBox(height: 8.h),
          AppText(
            text: AppStrings.noNotificationsDesc.tr(),
            fontSize: 14.sp,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

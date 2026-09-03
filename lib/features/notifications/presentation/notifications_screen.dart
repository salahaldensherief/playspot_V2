import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

import '../data/models/notification_model.dart';
import 'notifications_cubit.dart';
import 'notifications_state.dart';
import 'widgets/notification_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final lang = context.locale.languageCode;
        context.read<NotificationsCubit>().loadNotifications(lang);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 200) {
        final lang = context.locale.languageCode;
        context.read<NotificationsCubit>().loadMoreNotifications(lang);
      }
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    context.read<NotificationsCubit>().markAsRead(notification.id);

    final data = notification.data ?? {};
    final type = notification.type;

    if (type == NotificationType.booking) {
      final bookingId = _extractBookingId(
        data,
        "${notification.body} ${notification.title}",
      );
      if (bookingId.isNotEmpty) {
        context.pushNamed(
          RouterKeys.bookingDetails,
          pathParameters: {'id': bookingId},
        );
      } else {
        context.goNamed(RouterKeys.myBookings);
      }
    } else if (type == NotificationType.offer) {
      context.pushNamed(RouterKeys.myVouchers);

      final promoCode = _extractPromoCode(data, notification.body);
      if (promoCode.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: promoCode));
        GameHudToast.show(
          context,
          "Promo code copied: $promoCode",
          type: ToastType.success,
        );
      }
    } else if (type == NotificationType.loyalty) {
      context.goNamed(RouterKeys.home, extra: 2);
    } else {
      context.goNamed(RouterKeys.home);
    }
  }

  String _extractBookingId(Map<String, dynamic> data, String textFallback) {
    final possibleKeys = [
      'booking_id',
      'bookingId',
      'id',
      'target_id',
      'reference_id',
      'entity_id',
    ];
    for (final key in possibleKeys) {
      final val = data[key]?.toString().trim();
      if (val != null && val.isNotEmpty && val != 'null') {
        return val;
      }
    }
    final uuidMatch = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(textFallback);
    if (uuidMatch != null) {
      return uuidMatch.group(0) ?? '';
    }
    return '';
  }

  String _extractPromoCode(Map<String, dynamic> data, String textFallback) {
    final possibleKeys = ['promo_code', 'code', 'promoCode', 'coupon'];
    for (final key in possibleKeys) {
      final val = data[key]?.toString().trim();
      if (val != null && val.isNotEmpty && val != 'null') {
        return val;
      }
    }
    final codeMatch = RegExp(r'[A-Z0-9]{5,10}').firstMatch(textFallback);
    if (codeMatch != null) {
      return codeMatch.group(0) ?? '';
    }
    return '';
  }

  Future<void> _onRefresh() async {
    final lang = context.locale.languageCode;
    await context.read<NotificationsCubit>().refreshNotifications(lang);
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
                child: BlocListener<NotificationsCubit, NotificationsState>(
                  listenWhen: (previous, current) =>
                      previous.status != current.status &&
                      current.status == NotificationsStatus.error,
                  listener: (context, state) {
                    if (state.errorMessage != null &&
                        state.errorMessage!.isNotEmpty) {
                      GameHudToast.show(
                        context,
                        state.errorMessage!,
                        type: ToastType.error,
                      );
                    }
                  },
                  child: BlocBuilder<NotificationsCubit, NotificationsState>(
                    buildWhen: (previous, current) =>
                        previous.status != current.status ||
                        previous.notifications != current.notifications ||
                        previous.isLoadingMore != current.isLoadingMore ||
                        previous.hasMore != current.hasMore,
                    builder: (context, state) {
                      if (state.status == NotificationsStatus.loading &&
                          state.notifications.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.neonBlue,
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: AppColors.neonBlue,
                        backgroundColor: AppColors.cardBackground,
                        onRefresh: _onRefresh,
                        child: state.notifications.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.7,
                                  child: _buildEmptyState(),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: 16.allPadding,
                                itemCount: state.notifications.length +
                                    (state.isLoadingMore ? 1 : 0) +
                                    1,
                                itemBuilder: (context, index) {
                                  if (index < state.notifications.length) {
                                    final notification =
                                        state.notifications[index];
                                    return NotificationItem(
                                      notification: notification,
                                      onTap: () =>
                                          _handleNotificationTap(notification),
                                    );
                                  }

                                  if (index == state.notifications.length &&
                                      state.isLoadingMore) {
                                    return Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16.h),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.neonBlue,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    );
                                  }

                                  return const SafeBottomSpacer();
                                },
                              ),
                      );
                    },
                  ),
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
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          AppText(
            text: AppStrings.notifications.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: "Orbitron",
          ),
          Row(
            children: [
              IconButton(
                onPressed: _onRefresh,
                icon: const Icon(TablerIcons.refresh, color: AppColors.neonBlue),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.neonBlue.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: () =>
                    context.read<NotificationsCubit>().markAllAsRead(),
                icon: const Icon(TablerIcons.checks, color: AppColors.neonBlue),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.neonBlue.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ],
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
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120.w,
                height: 120.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonBlue.withValues(alpha: 0.1),
                      AppColors.transparent,
                    ],
                  ),
                ),
              ),
              Icon(
                TablerIcons.bell_off,
                size: 60.sp,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ],
          ),
          20.verticalSpace,
          AppText(
            text: AppStrings.noNotificationsYet.tr(),
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          12.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: AppText(
              text: AppStrings.noNotificationsDesc.tr(),
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

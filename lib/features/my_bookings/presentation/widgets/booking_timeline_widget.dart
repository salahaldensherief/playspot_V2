import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../../domain/entities/booking_timeline_item.dart';
import '../booking_timeline_cubit.dart';
import '../booking_timeline_state.dart';

class BookingTimelineWidget extends StatefulWidget {
  final String bookingId;

  const BookingTimelineWidget({
    super.key,
    required this.bookingId,
  });

  @override
  State<BookingTimelineWidget> createState() => _BookingTimelineWidgetState();
}

class _BookingTimelineWidgetState extends State<BookingTimelineWidget> {
  String _getLangCode(BuildContext context) {
    try {
      final easyLoc = EasyLocalization.of(context);
      if (easyLoc != null) return easyLoc.locale.languageCode;
      return Localizations.localeOf(context).languageCode;
    } catch (_) {
      return 'ar';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final lang = _getLangCode(context);
        final isArabic = lang == 'ar';
        final cubit = context.read<BookingTimelineCubit>();
        if (cubit.state.status == RequestStatus.initial) {
          cubit.fetchTimeline(widget.bookingId, isArabic: isArabic);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = _getLangCode(context);
    final isArabic = lang == 'ar';

    return BlocBuilder<BookingTimelineCubit, BookingTimelineState>(
      buildWhen: (previous, current) =>
          previous.status != current.status || previous.items != current.items,
      builder: (context, state) {
        if (state.status == RequestStatus.loading || state.status == RequestStatus.initial) {
          return _buildLoadingShimmer();
        }

        if (state.status == RequestStatus.failure) {
          return _buildErrorView(
            context,
            state.errorMessage ?? AppStrings.bookingTimelineFailed.tr(),
            isArabic,
          );
        }

        if (state.status == RequestStatus.success && state.items.isEmpty) {
          return _buildEmptyView();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    color: AppColors.neonBlue,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  AppText(
                    text: AppStrings.bookingTimelineTitle.tr(),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.items.length,
              separatorBuilder: (context, index) => SizedBox(height: 4.h),
              itemBuilder: (context, index) {
                final item = state.items[index];
                final isLast = index == state.items.length - 1;
                return _TimelineTileNode(
                  item: item,
                  isLast: isLast,
                  lang: lang,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120.w,
                        height: 14.h,
                        color: Colors.white,
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        width: 80.w,
                        height: 10.h,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error, bool isArabic) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: AppText(
                  text: error,
                  fontSize: 13.sp,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: 130.w,
              height: 36.h,
              child: AppButton(
                content: ButtonContent(
                  label: AppStrings.retry.tr(),
                ),
                buttonConfig: ButtonConfig(
                  height: 36.h,
                  backgroundColor: AppColors.danger,
                  borderRadius: 8.r,
                ),
                behavior: ButtonBehavior.tap(
                  onTap: () {
                    context.read<BookingTimelineCubit>().fetchTimeline(widget.bookingId, isArabic: isArabic);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: AppText(
              text: AppStrings.noTimelineUpdates.tr(),
              fontSize: 13.sp,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTileNode extends StatelessWidget {
  final BookingTimelineItem item;
  final bool isLast;
  final String lang;

  const _TimelineTileNode({
    required this.item,
    required this.isLast,
    required this.lang,
  });

  IconData _getIcon() {
    switch (item.eventCode.toLowerCase().trim()) {
      case 'booking_created':
      case 'created':
        return Icons.event_available_rounded;
      case 'booking_confirmed':
      case 'booking_approved':
      case 'approved':
      case 'confirmed':
        return Icons.verified_rounded;
      case 'booking_checked_in':
      case 'check_in':
      case 'checked_in':
      case 'session_started':
        return Icons.login_rounded;
      case 'booking_extension_requested':
        return Icons.more_time_rounded;
      case 'booking_extension_approved':
      case 'session_extended':
      case 'extended':
      case 'extension':
        return Icons.update_rounded;
      case 'booking_extension_rejected':
        return Icons.history_toggle_off_rounded;
      case 'booking_completed':
      case 'completed':
        return Icons.check_circle_rounded;
      case 'booking_cancelled':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getColor() {
    switch (item.eventCode.toLowerCase().trim()) {
      case 'booking_created':
      case 'created':
        return AppColors.neonBlue;
      case 'booking_confirmed':
      case 'booking_approved':
      case 'approved':
      case 'confirmed':
      case 'booking_checked_in':
      case 'check_in':
      case 'checked_in':
      case 'session_started':
      case 'booking_extension_approved':
      case 'booking_completed':
      case 'completed':
        return AppColors.success;
      case 'booking_extension_requested':
      case 'extended':
      case 'extension':
        return AppColors.warning;
      case 'booking_extension_rejected':
      case 'booking_cancelled':
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTimestamp(DateTime dt) {
    try {
      final formattedTime = DateFormat.jm(lang).format(dt);
      final formattedDate = DateFormat.yMMMd(lang).format(dt);
      return "$formattedDate - $formattedTime";
    } catch (_) {
      return dt.toIso8601String();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();
    final title = item.getTitle(lang);
    final timestampText = _formatTimestamp(item.occurredAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Indicator
          Column(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5.w),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16.sp,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          // Event Content
          Expanded(
            child: Container(
              padding: EdgeInsets.all(10.w),
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: title,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 4.h),
                  AppText(
                    text: timestampText,
                    fontSize: 11.sp,
                    color: Colors.white60,
                  ),
                  if (item.payload != null && (item.payload?.isNotEmpty ?? false)) ...[
                    SizedBox(height: 6.h),
                    _buildPayloadDetails(item.payload ?? const {}),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadDetails(Map<String, dynamic> payload) {
    final entries = payload.entries.where((e) => e.value != null).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final keyStr = e.key.replaceAll('_', ' ');
          final valStr = e.value.toString();
          return AppText(
            text: "$keyStr: $valStr",
            fontSize: 10.sp,
            color: Colors.white70,
          );
        }).toList(),
      ),
    );
  }
}

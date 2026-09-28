import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

import '../checkout_cubit.dart';
import '../checkout_state.dart';

class CheckoutLateArrivalBanner extends StatelessWidget {
  final LoungeModel lounge;

  const CheckoutLateArrivalBanner({
    super.key,
    required this.lounge,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) => previous.selectedMethod != current.selectedMethod,
      builder: (context, state) {
        final isCash = state.selectedMethod == PaymentMethod.cash;
        final graceMinutes = lounge.cashGracePeriodMinutes > 0
            ? lounge.cashGracePeriodMinutes
            : 10;

        final bannerColor = isCash ? AppColors.warning : AppColors.neonBlue;
        final iconData = isCash ? Icons.timer_outlined : Icons.verified_outlined;
        final isArabic = context.locale.languageCode == 'ar';

        final String titleText = isCash
            ? (isArabic ? "سياسة التأخير للدفع الكاش" : "Cash Late Arrival Policy")
            : (isArabic ? "سياسة التأخير للدفع الإلكتروني" : "E-Wallet Late Arrival Policy");

        String noticeText;
        if (isCash) {
          final rawMsg = AppStrings.cashLatePolicyNotice.tr(args: [graceMinutes.toString()]);
          if (rawMsg == AppStrings.cashLatePolicyNotice || rawMsg.contains('cashLatePolicyNotice')) {
            noticeText = isArabic
                ? "يرجى التواجد بالصالة قبل الموعد بـ $graceMinutes دقائق؛ في حالة التأخير يتم إلغاء الحجز تلقائياً لإتاحة الغرفة للآخرين."
                : "Please arrive at the lounge $graceMinutes minutes before your appointment; in case of delay, the booking will be automatically cancelled to free the room for others.";
          } else {
            noticeText = rawMsg;
          }
        } else {
          final rawMsg = AppStrings.prepaidLatePolicyNotice.tr();
          if (rawMsg == AppStrings.prepaidLatePolicyNotice || rawMsg.contains('prepaidLatePolicyNotice')) {
            noticeText = isArabic
                ? "يبدأ وقتك من موعد الحجز الرسمي، وأي تأخير يُخصم من وقت جلستك الفعلي للحفاظ على المواعيد."
                : "Your session time starts at the booked time; any delay will be deducted from your actual playing time.";
          } else {
            noticeText = rawMsg;
          }
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                child: child,
              ),
            );
          },
          child: Container(
            key: ValueKey<bool>(isCash),
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: bannerColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: bannerColor.withValues(alpha: 0.08),
                  blurRadius: 8.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: bannerColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        text: titleText,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: bannerColor,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      AppText(
                        text: noticeText,
                        fontSize: 12.sp,
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.4,
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

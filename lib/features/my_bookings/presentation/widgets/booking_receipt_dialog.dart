import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/constants/app_config.dart';
import 'package:playspot/core/di.dart';
import '../../data/models/booking_model.dart';
import '../../domain/usecases/get_booking_timeline_usecase.dart';
import '../booking_timeline_cubit.dart';
import 'booking_timeline_widget.dart';

class BookingReceiptDialog extends StatelessWidget {
  final BookingModel booking;

  const BookingReceiptDialog({super.key, required this.booking});

  static Future<void> show(BuildContext context, BookingModel booking) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider<BookingTimelineCubit>(
        create: (context) =>
            BookingTimelineCubit(sl<GetBookingTimelineUseCase>()),
        child: BookingReceiptDialog(booking: booking),
      ),
    );
  }

  String? _getEffectiveReceiptUrl() {
    if (booking.proofImageUrl != null &&
        booking.proofImageUrl!.trim().isNotEmpty &&
        booking.proofImageUrl != 'null' &&
        booking.proofImageUrl != 'undefined') {
      final clean = booking.proofImageUrl!.trim();
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        return clean;
      }
      final cleanPath = clean.replaceAll(
        RegExp(r'^(receipts/|payment-proofs/)'),
        '',
      );
      return '${AppConfig.supabaseUrl}/storage/v1/object/public/receipts/$cleanPath';
    }
    return null;
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: AppLoader()),
                  errorWidget: (context, url, error) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.danger,
                        size: 48.sp,
                      ),
                      SizedBox(height: 8.h),
                      AppText(
                        text: 'receipt_image_load_error'.tr(),
                        color: Colors.white70,
                        fontSize: 14.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40.h,
              right: 16.w,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final effectiveReceiptUrl = _getEffectiveReceiptUrl();
    final hasReceiptImage =
        effectiveReceiptUrl != null && effectiveReceiptUrl.isNotEmpty;
    final isCash = booking.paymentMethod?.toLowerCase() == 'cash';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GlassContainer(
        borderRadius: 24,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.neonBlue,
                          size: 22.sp,
                        ),
                        SizedBox(width: 8.w),
                        AppText(
                          text: AppStrings.bookingDetailsAndReceipt.tr(),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: AppStrings.close.tr(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Receipt Image Container or Fallback
                if (hasReceiptImage) ...[
                  GestureDetector(
                    onTap: () =>
                        _showFullScreenImage(context, effectiveReceiptUrl),
                    child: Container(
                      width: double.infinity,
                      height: 240.h,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.neonBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AppImage(
                              borderRadius: 0,
                              urlImg: effectiveReceiptUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholderWidget:
                                  const Center(child: AppLoader()),
                              errorWidget: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.textSecondary,
                                    size: 36.sp,
                                  ),
                                  SizedBox(height: 6.h),
                                  AppText(
                                    text: isArabic
                                        ? "عفواً، فشل تحميل صورة الإيصال"
                                        : "Failed to load receipt image",
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            // Zoom Overlay Hint
                            Positioned(
                              bottom: 10.h,
                              right: 10.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in_rounded,
                                      color: AppColors.neonBlue,
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    AppText(
                                      text: isArabic
                                          ? "تكبير الصورة"
                                          : "Tap to zoom",
                                      fontSize: 10.sp,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isCash
                              ? Icons.payments_outlined
                              : Icons.receipt_long_outlined,
                          color: AppColors.textSecondary,
                          size: 40.sp,
                        ),
                        SizedBox(height: 8.h),
                        AppText(
                          text: isCash
                              ? (isArabic
                                    ? "الدفع نقداً داخل الفرع"
                                    : "Cash payment at lounge")
                              : (isArabic
                                    ? "لم يتم إرفاق صورة إيصال لهذا الحجز"
                                    : "No receipt image attached"),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 16.h),

                // Details Card
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.borderDefault.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.storefront_rounded,
                        label: isArabic ? "الفرع" : "Lounge",
                        value: booking.loungeName,
                      ),
                      Divider(color: Colors.white10, height: 16.h),
                      _buildDetailRow(
                        icon: Icons.confirmation_number_outlined,
                        label: isArabic ? "رقم الحجز" : "Booking ID",
                        value:
                            "#${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}",
                      ),
                      if (booking.senderAccount != null &&
                          booking.senderAccount!.isNotEmpty) ...[
                        Divider(color: Colors.white10, height: 16.h),
                        _buildDetailRow(
                          icon: Icons.phone_android_rounded,
                          label: isArabic
                              ? "حساب/محفظة المحول"
                              : "Sender Account",
                          value: booking.senderAccount!,
                        ),
                      ],
                      if (booking.transactionReference != null &&
                          booking.transactionReference!.isNotEmpty) ...[
                        Divider(color: Colors.white10, height: 16.h),
                        _buildDetailRow(
                          icon: Icons.pin_outlined,
                          label: isArabic
                              ? "رقم المرجع / التحويل"
                              : "Reference No.",
                          value: booking.transactionReference!,
                        ),
                      ],
                      Divider(color: Colors.white10, height: 16.h),
                      _buildDetailRow(
                        icon: Icons.attach_money_rounded,
                        label: isArabic ? "المبلغ الإجمالي" : "Total Amount",
                        value:
                            "${booking.totalPrice.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}",
                        valueColor: AppColors.neonBlue,
                        isBold: true,
                      ),
                      Divider(color: Colors.white10, height: 16.h),
                      _buildDetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: isArabic ? "التاريخ" : "Date",
                        value: booking.date.toAppDateString(),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Booking Timeline Section
                BookingTimelineWidget(bookingId: booking.id),

                SizedBox(height: 20.h),

                // Action Close Button
                AppButton(
                  content: ButtonContent(label: isArabic ? "إغلاق" : "Close"),
                  buttonConfig: ButtonConfig(
                    height: 44.h,
                    backgroundColor: AppColors.transparent,
                    borderColor: AppColors.borderDefault,
                    borderRadius: 12.r,
                  ),
                  behavior: ButtonBehavior.tap(
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16.sp),
        SizedBox(width: 8.w),
        AppText(text: label, fontSize: 12.sp, color: AppColors.textSecondary),
        const Spacer(),
        Flexible(
          child: AppText(
            text: value,
            fontSize: 12.sp,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.white,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

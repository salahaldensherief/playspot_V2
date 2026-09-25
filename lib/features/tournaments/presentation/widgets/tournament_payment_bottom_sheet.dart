import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../art_core/widgets/notifications/game_hud_toast.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class TournamentPaymentBottomSheet extends StatefulWidget {
  final double entryFee;
  final String? vodafoneCashNumber;
  final String? instaPayAccount;
  final Function(String paymentMethod, File receiptFile) onSubmit;

  const TournamentPaymentBottomSheet({
    super.key,
    required this.entryFee,
    this.vodafoneCashNumber,
    this.instaPayAccount,
    required this.onSubmit,
  });

  static Future<void> show({
    required BuildContext context,
    required double entryFee,
    String? vodafoneCashNumber,
    String? instaPayAccount,
    required Function(String paymentMethod, File receiptFile) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => TournamentPaymentBottomSheet(
        entryFee: entryFee,
        vodafoneCashNumber: vodafoneCashNumber,
        instaPayAccount: instaPayAccount,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<TournamentPaymentBottomSheet> createState() => _TournamentPaymentBottomSheetState();
}

class _TournamentPaymentBottomSheetState extends State<TournamentPaymentBottomSheet> {
  String _selectedMethod = 'Vodafone Cash';
  String _vodafoneCashNumber = '';
  String _instaPayAccount = '';
  bool _hasVodafoneCash = false;
  bool _hasInstaPay = false;
  File? _receiptFile;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _vodafoneCashNumber = widget.vodafoneCashNumber?.trim() ?? '';
    _instaPayAccount = widget.instaPayAccount?.trim() ?? '';

    _hasVodafoneCash = _vodafoneCashNumber.isNotEmpty;
    _hasInstaPay = _instaPayAccount.isNotEmpty;

    if (_hasVodafoneCash) {
      _selectedMethod = 'Vodafone Cash';
    } else if (_hasInstaPay) {
      _selectedMethod = 'InstaPay';
    }
  }

  String get _activeDestination => _selectedMethod == 'Vodafone Cash' ? _vodafoneCashNumber : _instaPayAccount;

  void _copyDestination() {
    Clipboard.setData(ClipboardData(text: _activeDestination));
    GameHudToast.show(
      context,
      AppStrings.codeCopied.tr(),
      type: ToastType.success,
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (picked != null) {
        final file = File(picked.path);
        final length = await file.length();
        if (length > 5 * 1024 * 1024) {
          if (mounted) {
            GameHudToast.show(
              context,
              'Receipt image must be under 5MB',
              type: ToastType.error,
            );
          }
          return;
        }
        setState(() {
          _receiptFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        GameHudToast.show(
          context,
          AppStrings.errorPickingImage.tr(args: ['$e']),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showMethodSelector = _hasVodafoneCash && _hasInstaPay;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsetsDirectional.only(
        start: 24.w,
        end: 24.w,
        top: 24.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.w,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(TablerIcons.receipt_2, color: AppColors.neonBlue, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppText(
                  text: AppStrings.paymentInstructions.tr(),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Entry Fee Display
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: _selectedMethod == 'Vodafone Cash'
                        ? AppStrings.vodafoneCashWalletNumber.tr()
                        : AppStrings.instaPayDetails.tr(),
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: AppText(
                          text: _activeDestination.isNotEmpty ? _activeDestination : AppStrings.noInternetConnection.tr(),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonBlue,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (_activeDestination.isNotEmpty)
                        GestureDetector(
                          onTap: _copyDestination,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppColors.neonBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(TablerIcons.copy, size: 14.sp, color: AppColors.neonBlue),
                                SizedBox(width: 4.w),
                                AppText(
                                  text: AppStrings.copyNumber.tr(),
                                  fontSize: 12.sp,
                                  color: AppColors.neonBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Divider(color: AppColors.borderDefault, height: 1.h),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        text: AppStrings.entryFee.tr(),
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                      AppText(
                        text: "${widget.entryFee.toStringAsFixed(2)} ${AppStrings.egp.tr()}",
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Payment Method Selector
          if (showMethodSelector) ...[
            AppText(
              text: AppStrings.paymentMethod.tr(),
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                if (_hasVodafoneCash)
                  Expanded(
                    child: _buildMethodTile(
                      title: 'Vodafone Cash',
                      isSelected: _selectedMethod == 'Vodafone Cash',
                      icon: TablerIcons.wallet,
                      onTap: () => setState(() => _selectedMethod = 'Vodafone Cash'),
                    ),
                  ),
                if (_hasVodafoneCash && _hasInstaPay) SizedBox(width: 12.w),
                if (_hasInstaPay)
                  Expanded(
                    child: _buildMethodTile(
                      title: 'InstaPay',
                      isSelected: _selectedMethod == 'InstaPay',
                      icon: TablerIcons.device_mobile,
                      onTap: () => setState(() => _selectedMethod = 'InstaPay'),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
          ],

          // Upload Receipt Section
          AppText(
            text: AppStrings.uploadReceipt.tr(),
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          SizedBox(height: 8.h),

          if (_receiptFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.file(
                    _receiptFile!,
                    height: 150.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    radius: 16,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _receiptFile = null),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickReceipt(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Column(
                        children: [
                          Icon(TablerIcons.photo, color: AppColors.neonBlue, size: 24.sp),
                          SizedBox(height: 6.h),
                          AppText(
                            text: AppStrings.selectReceiptImage.tr(),
                            fontSize: 11.sp,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickReceipt(ImageSource.camera),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Column(
                        children: [
                          Icon(TablerIcons.camera, color: AppColors.neonPurple, size: 24.sp),
                          SizedBox(height: 6.h),
                          AppText(
                            text: AppStrings.camera.tr(),
                            fontSize: 11.sp,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 20.h),

          // Submit Button
          AppButton(
            content: ButtonContent(label: AppStrings.submitPayment.tr()),
            buttonConfig: ButtonConfig(
              height: 48.h,
              gradient: AppColors.primaryGradient,
              borderRadius: 12.r,
            ),
            behavior: ButtonBehavior.tap(
              isEnabled: _receiptFile != null && !_isUploading,
              onTap: () async {
                if (_receiptFile == null) {
                  GameHudToast.show(
                    context,
                    AppStrings.uploadReceipt.tr(),
                    type: ToastType.error,
                  );
                  return;
                }
                setState(() => _isUploading = true);
                final nav = Navigator.of(context);
                await widget.onSubmit(_selectedMethod, _receiptFile!);
                if (mounted) {
                  setState(() => _isUploading = false);
                  nav.pop();
                }
              },
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildMethodTile({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.1) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            AppText(
              text: title,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.neonBlue : AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

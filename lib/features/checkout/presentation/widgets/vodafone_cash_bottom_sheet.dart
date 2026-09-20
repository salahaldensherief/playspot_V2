import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/services/contact_launcher_service.dart';
import 'package:playspot/features/profile/data/datasources/remote/support_remote_data_source.dart';

class VodafoneCashBottomSheet extends StatefulWidget {
  final double amount;
  final String walletNumber;
  final String? instaPayAccount;
  final String loungeName;
  final String? initialMethod;
  final Function(String paymentMethod, File? receiptFile, String senderPhone) onConfirm;

  const VodafoneCashBottomSheet({
    super.key,
    required this.amount,
    this.walletNumber = '',
    this.instaPayAccount,
    required this.loungeName,
    this.initialMethod,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required double amount,
    required String loungeName,
    required Function(String paymentMethod, File? receiptFile, String senderPhone) onConfirm,
    String walletNumber = '',
    String? instaPayAccount,
    String? initialMethod,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => VodafoneCashBottomSheet(
        amount: amount,
        walletNumber: walletNumber,
        instaPayAccount: instaPayAccount,
        loungeName: loungeName,
        initialMethod: initialMethod,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<VodafoneCashBottomSheet> createState() => _VodafoneCashBottomSheetState();
}

class _VodafoneCashBottomSheetState extends State<VodafoneCashBottomSheet> {
  final _senderPhoneController = TextEditingController();
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
    _vodafoneCashNumber = widget.walletNumber.trim();
    _instaPayAccount = widget.instaPayAccount?.trim() ?? '';
    
    _hasVodafoneCash = _vodafoneCashNumber.isNotEmpty;
    _hasInstaPay = _instaPayAccount.isNotEmpty;

    // Set initial selection
    if (widget.initialMethod != null && widget.initialMethod!.isNotEmpty) {
      _selectedMethod = widget.initialMethod!;
    } else if (_hasVodafoneCash) {
      _selectedMethod = 'Vodafone Cash';
    } else if (_hasInstaPay) {
      _selectedMethod = 'InstaPay';
    }

    _fetchFallbackSettingsIfNeeded();
  }

  Future<void> _fetchFallbackSettingsIfNeeded() async {
    // If lounge didn't provide any payment methods, fetch fallback support settings
    if (!_hasVodafoneCash && !_hasInstaPay) {
      try {
        final settings = await sl<SupportRemoteDataSource>().getSupportSettings();
        if (settings.isNotEmpty) {
          final vcNumber = settings['vodafone_cash_number']?.toString().trim() ?? settings['vodafone_cash']?.toString().trim();
          final ipAccount = settings['instapay_account']?.toString().trim() ?? settings['instapay_number']?.toString().trim() ?? settings['instapay']?.toString().trim();

          setState(() {
            if (vcNumber != null && vcNumber.isNotEmpty) {
              _vodafoneCashNumber = vcNumber;
              _hasVodafoneCash = true;
              _selectedMethod = 'Vodafone Cash';
            }
            if (ipAccount != null && ipAccount.isNotEmpty) {
              _instaPayAccount = ipAccount;
              _hasInstaPay = true;
              if (!_hasVodafoneCash) {
                _selectedMethod = 'InstaPay';
              }
            }
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _senderPhoneController.dispose();
    super.dispose();
  }

  String get _activeDestination => _selectedMethod == 'Vodafone Cash' ? _vodafoneCashNumber : _instaPayAccount;

  void _copyDestination() {
    Clipboard.setData(ClipboardData(text: _activeDestination));
    HapticFeedback.lightImpact();
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
        setState(() {
          _receiptFile = File(picked.path);
        });
      }
    } catch (e) {
      GameHudToast.show(
        context,
        AppStrings.somethingWentWrong.tr(),
        type: ToastType.error,
      );
    }
  }

  Future<void> _launchWhatsApp() async {
    final senderPhone = _senderPhoneController.text.trim();
    final message = "أهلاً PlaySpot 👋\n"
        "أود تأكيد تحويل ${_selectedMethod} بقيمة ${widget.amount.toStringAsFixed(0)} ج.م "
        "لصالة ${widget.loungeName}.\n"
        "${senderPhone.isNotEmpty ? 'رقم المحفظة / الحساب المحول منها: $senderPhone' : ''}";

    await ContactLauncherService.launchWhatsApp(
      phone: _vodafoneCashNumber.isNotEmpty ? _vodafoneCashNumber : '01012345678',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMethodSelector = _hasVodafoneCash && _hasInstaPay;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
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

          // Payment Method Selector (Only shown if both are configured)
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
                      imagePath: AssetsManager.vodafoneCashLogo,
                      imageFit: BoxFit.cover,
                      imageBorderRadius: 6.r,
                      onTap: () => setState(() => _selectedMethod = 'Vodafone Cash'),
                    ),
                  ),
                if (_hasVodafoneCash && _hasInstaPay) SizedBox(width: 12.w),
                if (_hasInstaPay)
                  Expanded(
                    child: _buildMethodTile(
                      title: 'InstaPay',
                      isSelected: _selectedMethod == 'InstaPay',
                      imagePath: AssetsManager.instaPayLogo,
                      imageBgColor: Colors.white,
                      imageBorderRadius: 4.r,
                      onTap: () => setState(() => _selectedMethod = 'InstaPay'),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
          ],

          // Active Account & Amount Card
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
                          text: _activeDestination.isNotEmpty ? _activeDestination : '---',
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
                        text: AppStrings.totalAmount.tr(),
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                      AppText(
                        text: "${widget.amount.toStringAsFixed(2)} ${AppStrings.egp.tr()}",
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

          // Sender Phone Field
          AppTextField(
            controller: _senderPhoneController,
            label: AppStrings.userWalletPhone.tr(),
            hint: AppStrings.userWalletPhoneHint.tr(),
            textInputType: TextInputType.phone,
          ),
          SizedBox(height: 16.h),

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

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  content: ButtonContent(
                    label: AppStrings.confirmViaWhatsApp.tr(),
                    icon: Icon(TablerIcons.brand_whatsapp, color: Colors.green, size: 18.sp),
                  ),
                  buttonConfig: ButtonConfig(
                    height: 48.h,
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    borderColor: Colors.green,
                    borderRadius: 12.r,
                    textStyle: TextStyle(color: Colors.green, fontSize: 12.sp, fontWeight: FontWeight.bold),
                  ),
                  behavior: ButtonBehavior.tap(
                    onTap: _launchWhatsApp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  content: ButtonContent(
                    label: AppStrings.confirmAndPay.tr(),
                  ),
                  buttonConfig: ButtonConfig(
                    height: 48.h,
                    gradient: AppColors.primaryGradient,
                    borderRadius: 12.r,
                  ),
                  behavior: ButtonBehavior.tap(
                    isEnabled: _receiptFile != null && !_isUploading,
                    onTap: () async {
                      final phone = _senderPhoneController.text.trim();
                      if (phone.isEmpty) {
                        final isEnglish = context.locale.languageCode == 'en';
                        GameHudToast.show(
                          context,
                          isEnglish
                              ? 'Sender wallet/phone number is required for manual transfer.'
                              : 'يجب إدخال رقم المحفظة الذي تم التحويل منه.',
                          type: ToastType.error,
                        );
                        return;
                      }
                      if (_receiptFile == null) {
                        GameHudToast.show(
                          context,
                          AppStrings.uploadReceipt.tr(),
                          type: ToastType.error,
                        );
                        return;
                      }
                      setState(() => _isUploading = true);
                      Navigator.pop(context);
                      widget.onConfirm(_selectedMethod, _receiptFile, phone);
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildMethodTile({
    required String title,
    required bool isSelected,
    String? imagePath,
    BoxFit imageFit = BoxFit.contain,
    Color? imageBgColor,
    double? imageBorderRadius,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
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
            if (imagePath != null)
              Container(
                decoration: BoxDecoration(
                  color: imageBgColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(imageBorderRadius ?? 4.r),
                ),
                padding: imageBgColor != null ? EdgeInsets.all(2.w) : EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageBorderRadius ?? 4.r),
                  child: Image.asset(
                    imagePath,
                    width: 20.w,
                    height: 20.w,
                    fit: imageFit,
                  ),
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                size: 18.sp,
              ),
            SizedBox(width: 6.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AppText(
                  text: title,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.neonBlue : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

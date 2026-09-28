import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playspot/art_core/app_strings.dart';
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
import 'package:playspot/core/utils/image_picker_utils.dart';
import 'package:playspot/core/utils/payment_form_validators.dart';
import 'package:playspot/features/profile/data/datasources/remote/support_remote_data_source.dart';

class ManualPaymentBottomSheet extends StatefulWidget {
  final double amount;
  final String? walletNumber;
  final String? instaPayAccount;
  final String loungeName;
  final Function(
    String paymentMethod,
    File receiptFile,
    String senderAccount,
    String transactionReference,
  ) onConfirm;

  const ManualPaymentBottomSheet({
    super.key,
    required this.amount,
    this.walletNumber,
    this.instaPayAccount,
    required this.loungeName,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required double amount,
    required String loungeName,
    String? walletNumber,
    String? instaPayAccount,
    required Function(
      String paymentMethod,
      File receiptFile,
      String senderAccount,
      String transactionReference,
    ) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => ManualPaymentBottomSheet(
        amount: amount,
        walletNumber: walletNumber,
        instaPayAccount: instaPayAccount,
        loungeName: loungeName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ManualPaymentBottomSheet> createState() => _ManualPaymentBottomSheetState();
}

class _ManualPaymentBottomSheetState extends State<ManualPaymentBottomSheet> {
  final _senderAccountController = TextEditingController();
  final _transactionRefController = TextEditingController();

  String _selectedMethod = 'Vodafone Cash';
  String _vodafoneCashNumber = '';
  String _instaPayAccount = '';
  bool _hasVodafoneCash = false;
  bool _hasInstaPay = false;
  File? _receiptFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _vodafoneCashNumber = widget.walletNumber?.trim() ?? '';
    _instaPayAccount = widget.instaPayAccount?.trim() ?? '';

    _hasVodafoneCash = _vodafoneCashNumber.isNotEmpty;
    _hasInstaPay = _instaPayAccount.isNotEmpty;

    if (_hasVodafoneCash) {
      _selectedMethod = 'Vodafone Cash';
    } else if (_hasInstaPay) {
      _selectedMethod = 'InstaPay';
    }

    _fetchFallbackSettingsIfNeeded();
  }

  Future<void> _fetchFallbackSettingsIfNeeded() async {
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
    _senderAccountController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  String get _activeDestination => _selectedMethod == 'Vodafone Cash' ? _vodafoneCashNumber : _instaPayAccount;

  void _copyDestination() {
    if (_activeDestination.isEmpty) return;
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
      final compressedFile = await ImagePickerUtils.pickAndCompressImage(source);
      if (compressedFile != null && mounted) {
        setState(() {
          _receiptFile = compressedFile;
        });
      }
    } catch (e) {
      if (!mounted) return;
      GameHudToast.show(
        context,
        AppStrings.somethingWentWrong.tr(),
        type: ToastType.error,
      );
    }
  }

  Future<void> _launchWhatsApp() async {
    final senderAccount = _senderAccountController.text.trim();
    final transRef = _transactionRefController.text.trim();
    final message = "أهلاً PlaySpot 👋\n"
        "أود تأكيد تحويل $_selectedMethod بقيمة ${widget.amount.toStringAsFixed(0)} ج.م "
        "لصالة ${widget.loungeName}.\n"
        "${senderAccount.isNotEmpty ? 'حساب / رقم التحويل: $senderAccount\n' : ''}"
        "${transRef.isNotEmpty ? 'الرقم المرجعي: $transRef' : ''}";

    await ContactLauncherService.launchWhatsApp(
      phone: _vodafoneCashNumber.isNotEmpty ? _vodafoneCashNumber : '01012345678',
      message: message,
    );
  }

  void _handleSubmit() {
    final isArabic = context.locale.languageCode == 'ar';
    final senderAccount = _senderAccountController.text.trim();
    final transRef = _transactionRefController.text.trim();

    final accountError = PaymentFormValidators.validateSenderAccount(senderAccount, isArabic: isArabic);
    if (accountError != null) {
      GameHudToast.show(
        context,
        accountError,
        type: ToastType.error,
      );
      return;
    }

    final refError = PaymentFormValidators.validateTransactionReference(transRef, isArabic: isArabic);
    if (refError != null) {
      GameHudToast.show(
        context,
        refError,
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
    widget.onConfirm(_selectedMethod, _receiptFile!, senderAccount, transRef);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
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

          AppTextField(
            controller: _senderAccountController,
            label: isArabic ? 'رقم المحفظة / حساب InstaPay المحول منه' : 'Sender Wallet / InstaPay Handle',
            hint: isArabic ? 'مثال: 01012345678 أو username@instapay' : 'e.g., 01012345678 or username@instapay',
            textInputType: TextInputType.text,
          ),
          SizedBox(height: 12.h),

          AppTextField(
            controller: _transactionRefController,
            label: isArabic ? 'الرقم المرجعي للتحويل' : 'Transaction Reference Number',
            hint: isArabic ? 'أدخل الرقم المرجعي المكون من 6 أرقام/حروف على الأقل' : 'Enter transaction reference (min 6 characters)',
            textInputType: TextInputType.text,
          ),
          SizedBox(height: 16.h),

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
                    isEnabled: !_isUploading,
                    onTap: _handleSubmit,
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

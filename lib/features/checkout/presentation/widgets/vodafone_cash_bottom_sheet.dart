import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
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
import 'package:playspot/features/profile/data/datasources/remote/support_remote_data_source.dart';

class VodafoneCashBottomSheet extends StatefulWidget {
  final double amount;
  final String walletNumber;
  final String loungeName;
  final ValueChanged<String> onConfirm;

  const VodafoneCashBottomSheet({
    super.key,
    required this.amount,
    this.walletNumber = '01012345678',
    required this.loungeName,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required double amount,
    required String loungeName,
    required ValueChanged<String> onConfirm,
    String walletNumber = '01012345678',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: VodafoneCashBottomSheet(
          amount: amount,
          walletNumber: walletNumber,
          loungeName: loungeName,
          onConfirm: onConfirm,
        ),
      ),
    );
  }

  @override
  State<VodafoneCashBottomSheet> createState() => _VodafoneCashBottomSheetState();
}

class _VodafoneCashBottomSheetState extends State<VodafoneCashBottomSheet> {
  final _senderPhoneController = TextEditingController();
  late String _activeWalletNumber;

  @override
  void initState() {
    super.initState();
    _activeWalletNumber = widget.walletNumber;
    _fetchDynamicWalletNumber();
  }

  Future<void> _fetchDynamicWalletNumber() async {
    try {
      final settings = await sl<SupportRemoteDataSource>().getSupportSettings();
      if (settings.isNotEmpty && settings['vodafone_cash_number'] != null) {
        final number = settings['vodafone_cash_number'].toString().trim();
        if (number.isNotEmpty) {
          setState(() {
            _activeWalletNumber = number;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _senderPhoneController.dispose();
    super.dispose();
  }

  void _copyWalletNumber() {
    Clipboard.setData(ClipboardData(text: _activeWalletNumber));
    HapticFeedback.lightImpact();
    GameHudToast.show(
      context,
      AppStrings.codeCopied.tr(),
      type: ToastType.success,
    );
  }

  Future<void> _launchWhatsApp() async {
    final senderPhone = _senderPhoneController.text.trim();
    final message = "أهلاً PlaySpot 👋\n"
        "أود تأكيد تحويل فودافون كاش بقيمة ${widget.amount.toStringAsFixed(0)} ج.م "
        "لصالة ${widget.loungeName}.\n"
        "${senderPhone.isNotEmpty ? 'رقم المحفظة المحول منها: $senderPhone' : ''}";

    final success = await ContactLauncherService.launchWhatsApp(
      phone: _activeWalletNumber,
      message: message,
    );

    if (!success && mounted) {
      GameHudToast.show(
        context,
        AppStrings.somethingWentWrong.tr(),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
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
                child: Icon(TablerIcons.device_mobile, color: AppColors.neonBlue, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppText(
                  text: AppStrings.vodafoneCashTitle.tr(),
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
          SizedBox(height: 20.h),
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: AppStrings.vodafoneCashWalletNumber.tr(),
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        text: _activeWalletNumber,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonBlue,
                      ),
                      GestureDetector(
                        onTap: _copyWalletNumber,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: AppColors.neonBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
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
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.neonBlue, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: AppText(
                    text: AppStrings.vodafoneCashInstructions.tr(),
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          AppTextField(
            controller: _senderPhoneController,
            label: AppStrings.userWalletPhone.tr(),
            hint: AppStrings.userWalletPhoneHint.tr(),
            textInputType: TextInputType.phone,
          ),
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
                    textStyle: TextStyle(color: Colors.green, fontSize: 13.sp, fontWeight: FontWeight.bold),
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
                    onTap: () {
                      final phone = _senderPhoneController.text.trim();
                      Navigator.pop(context);
                      widget.onConfirm(phone);
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
}

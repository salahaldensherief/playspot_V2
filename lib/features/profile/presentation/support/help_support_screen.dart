import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
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

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _selectedCategory = AppStrings.issueCategoryBooking;
  bool _isSubmitting = false;

  String _whatsappPhone = '01012345678';
  String _supportPhone = '01012345678';
  String _supportEmail = 'support@playspot.app';

  List<Map<String, String>> _faqs = [
    {
      'q': 'كيف أقوم بالدفع عبر فودافون كاش؟',
      'a': 'عند اختيار فودافون كاش في صفحة الدفع، سيظهر لك رقم محفظة PlaySpot المعتمد. قم بتحويل المبلغ عبر *9# أو تطبيق أنا فودافون، ثم أدخل رقم محفظتك للتحقق وإتمام الحجز.',
    },
    {
      'q': 'كيف أستخدم كود دفع فوري؟',
      'a': 'عند اختيار فوري، يتولد كود مرجعي مكون من 9 أرقام. يمكنك التوجه لأي كشك أو فرع فوري أو استخدام تطبيق فوري والسداد عبر كود الخدمة (788) برقم المرجع خلال ساعتين.',
    },
    {
      'q': 'ما هي سياسة إلغاء الحجز والاسترجاع؟',
      'a': 'يمكنك إلغاء الحجز قبل موعده بساعتين على الأقل للحصول على استرداد كامل لقيمة الحجز في محفظة نقاطك أو عبر وسيلة الدفع الأصلية.',
    },
    {
      'q': 'ماذا يحدث إذا تأخرت عن موعد الحجز؟',
      'a': 'يتم حفظ حجزك لمدة 15 دقيقة من بداية الوقت المحجوز. في حال التأخر عن ذلك دون إبلاغ الصالة، قد يتم تحرير الغرفة لحجوزات أخرى.',
    },
    {
      'q': 'كيف أستفيد من برنامج المكافآت والنقاط؟',
      'a': 'تكسب نقاطاً مع كل حجز مؤكد وعند دعوة أصدقائك عبر كود الإحالة. يمكنك استبدال هذه النقاط بساعات مجانية أو خصومات من شاشة "استبدال النقاط".',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSupportData();
  }

  Future<void> _loadSupportData() async {
    try {
      final dataSource = sl<SupportRemoteDataSource>();
      final settings = await dataSource.getSupportSettings();
      if (settings.isNotEmpty) {
        setState(() {
          if (settings['whatsapp_phone'] != null && settings['whatsapp_phone'].toString().isNotEmpty) {
            _whatsappPhone = settings['whatsapp_phone'].toString();
          }
          if (settings['support_phone'] != null && settings['support_phone'].toString().isNotEmpty) {
            _supportPhone = settings['support_phone'].toString();
          }
          if (settings['support_email'] != null && settings['support_email'].toString().isNotEmpty) {
            _supportEmail = settings['support_email'].toString();
          }
        });
      }

      if (!mounted) return;
      final lang = context.locale.languageCode;
      final remoteFaqs = await dataSource.getFaqs(lang);
      if (remoteFaqs.isNotEmpty) {
        final parsedFaqs = remoteFaqs.map((item) {
          final q = item['question_$lang'] ?? item['question_ar'] ?? item['question_en'] ?? item['question'] ?? '';
          final a = item['answer_$lang'] ?? item['answer_ar'] ?? item['answer_en'] ?? item['answer'] ?? '';
          return {'q': q.toString(), 'a': a.toString()};
        }).where((f) => f['q']!.isNotEmpty).toList();

        if (parsedFaqs.isNotEmpty) {
          setState(() {
            _faqs = parsedFaqs;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      await sl<SupportRemoteDataSource>().createSupportTicket(
        issueType: _selectedCategory,
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageController.clear();
      });
      GameHudToast.show(
        context,
        AppStrings.ticketSentSuccess.tr(),
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      GameHudToast.show(
        context,
        AppStrings.ticketSentSuccess.tr(),
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      AppStrings.issueCategoryBooking,
      AppStrings.issueCategoryPayment,
      AppStrings.issueCategoryTechnical,
      AppStrings.issueCategoryOther,
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButtonWidget(),
        title: AppText(
          text: AppStrings.helpSupportTitle.tr(),
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.supportContactUs.tr(),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 14.h),
            _buildContactActions(),
            SizedBox(height: 28.h),
            AppText(
              text: AppStrings.sendSupportTicket.tr(),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 14.h),
            _buildSupportForm(categories),
            SizedBox(height: 28.h),
            AppText(
              text: AppStrings.faqTitle.tr(),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 14.h),
            _buildFaqSection(),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildContactActions() {
    return Row(
      children: [
        Expanded(
          child: _buildContactCard(
            icon: TablerIcons.brand_whatsapp,
            color: Colors.green,
            title: AppStrings.supportWhatsApp.tr(),
            onTap: () async {
              final success = await ContactLauncherService.launchWhatsApp(
                phone: _whatsappPhone,
                message: 'أهلاً PlaySpot، أحتاج مساعدة في:',
              );
              if (!success && mounted) {
                GameHudToast.show(context, AppStrings.somethingWentWrong.tr(), type: ToastType.error);
              }
            },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildContactCard(
            icon: TablerIcons.phone_call,
            color: AppColors.neonBlue,
            title: AppStrings.supportCall.tr(),
            onTap: () async {
              final success = await ContactLauncherService.launchPhoneCall(_supportPhone);
              if (!success && mounted) {
                GameHudToast.show(context, AppStrings.somethingWentWrong.tr(), type: ToastType.error);
              }
            },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildContactCard(
            icon: TablerIcons.mail,
            color: AppColors.neonPurple,
            title: AppStrings.supportEmail.tr(),
            onTap: () async {
              final success = await ContactLauncherService.launchEmail(
                email: _supportEmail,
                subject: 'PlaySpot Support',
              );
              if (!success && mounted) {
                GameHudToast.show(context, AppStrings.somethingWentWrong.tr(), type: ToastType.error);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 16,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22.sp),
              ),
              SizedBox(height: 10.h),
              AppText(
                text: title,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportForm(List<String> categories) {
    return GlassContainer(
      borderRadius: 20,
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                text: AppStrings.selectIssueCategory.tr(),
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.cardBackground,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.neonBlue),
                    items: categories.map((catKey) {
                      return DropdownMenuItem<String>(
                        value: catKey,
                        child: AppText(
                          text: catKey.tr(),
                          fontSize: 14.sp,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              AppTextField(
                controller: _messageController,
                label: AppStrings.describeIssue.tr(),
                hint: AppStrings.describeIssue.tr(),
                maxLines: 4,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return AppStrings.isRequired.tr();
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              AppButton(
                content: ButtonContent(
                  label: _isSubmitting ? AppStrings.processing.tr() : AppStrings.sendSupportTicket.tr(),
                ),
                buttonConfig: ButtonConfig(
                  height: 48.h,
                  gradient: AppColors.primaryGradient,
                  borderRadius: 12.r,
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: !_isSubmitting,
                  onTap: _submitTicket,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    return Column(
      children: _faqs.map((faq) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: GlassContainer(
            borderRadius: 16,
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              iconColor: AppColors.neonBlue,
              collapsedIconColor: AppColors.textSecondary,
              title: AppText(
                text: faq['q'] ?? '',
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: AppText(
                    text: faq['a'] ?? '',
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

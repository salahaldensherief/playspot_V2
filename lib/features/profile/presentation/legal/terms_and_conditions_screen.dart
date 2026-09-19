import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/profile/data/datasources/remote/support_remote_data_source.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, String>> _remoteTerms = [];
  List<Map<String, String>> _remotePrivacy = [];
  List<Map<String, String>> _remoteRefund = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    try {
      final lang = context.locale.languageCode;
      final policies = await sl<SupportRemoteDataSource>().getPolicies(lang);
      if (policies.isNotEmpty) {
        for (final policy in policies) {
          final type = (policy['type'] ?? policy['policy_type'])?.toString();
          final content = policy['content_$lang'] ?? policy['content_ar'] ?? policy['content_en'] ?? policy['content'];

          List<Map<String, String>> parsedItems = [];
          if (content is List) {
            for (final item in content) {
              if (item is Map) {
                final t = item['title'] ?? item['t'] ?? '';
                final c = item['content'] ?? item['c'] ?? '';
                if (t.toString().isNotEmpty) {
                  parsedItems.add({'t': t.toString(), 'c': c.toString()});
                }
              }
            }
          }

          if (parsedItems.isNotEmpty) {
            setState(() {
              if (type == 'terms_of_service' || type == 'terms') {
                _remoteTerms = parsedItems;
              } else if (type == 'privacy_policy' || type == 'privacy') {
                _remotePrivacy = parsedItems;
              } else if (type == 'refund_policy' || type == 'refund') {
                _remoteRefund = parsedItems;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButtonWidget(),
        title: AppText(
          text: AppStrings.termsOfService.tr(),
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.h),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: AppColors.primaryGradient,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: AppStrings.termsTab.tr()),
                Tab(text: AppStrings.privacyTab.tr()),
                Tab(text: AppStrings.refundTab.tr()),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsSection(isArabic),
          _buildPrivacySection(isArabic),
          _buildRefundSection(isArabic),
        ],
      ),
    );
  }

  Widget _buildTermsSection(bool isArabic) {
    if (_remoteTerms.isNotEmpty) {
      return _buildPolicyList(_remoteTerms, TablerIcons.file_text);
    }

    final items = isArabic
        ? [
            {'t': '١. قبول الشروط', 'c': 'باستخدامك لتطبيق PlaySpot، فإنك توافق على الالتزام بكافة الشروط والأحكام المدونة والقوانين السارية.'},
            {'t': '٢. حجز الغرف والأجهزة', 'c': 'جميع الحجوزات تتوقف على توافر الغرف في الصالات المعتمدة. يجب التأكد من تفاصيل الوقت والأجهزة قبل تأكيد الحجز.'},
            {'t': '٣. السلوك والمحافظة على الممتلكات', 'c': 'يلتزم المستخدم باحترام تعليمات صالة الألعاب والحفاظ على الأجهزة والمعدات. أي أضرار يتم التسبب بها يرجع تعويضها على المستخدم.'},
            {'t': '٤. طرق الدفع والتحويل', 'c': 'يدعم التطبيق وسائل دفع متعددة (فودافون كاش، فوري، كاش بالصالة، وبطاقات الائتمان). يلزم سداد القيمة خلال المدة المحددة لتأكيد الحجز.'},
            {'t': '٥. برنامج المكافآت والنقاط', 'c': 'النقاط التي تكتسبها من الحجوزات أو الإحالات غير قابلة للتحويل لنقدية خارج التطبيق، وتُستخدم حصرياً لاستبدال مكافآت وساعات لعب مجانية.'},
          ]
        : [
            {'t': '1. Acceptance of Terms', 'c': 'By downloading and using PlaySpot, you agree to comply with all terms and applicable laws.'},
            {'t': '2. Room & Station Booking', 'c': 'All bookings depend on availability. Please verify time, date, and gaming station details before confirming.'},
            {'t': '3. User Conduct & Property Care', 'c': 'Users must respect lounge equipment and policies. Any damages caused to devices are the responsibility of the user.'},
            {'t': '4. Payment Methods', 'c': 'We support Vodafone Cash, Fawry, Cash at Lounge, and Credit Cards. Timely payment is required to confirm bookings.'},
            {'t': '5. Rewards & Loyalty Points', 'c': 'Points earned have no monetary value outside PlaySpot and can only be redeemed for in-app rewards and free gaming hours.'},
          ];

    return _buildPolicyList(items, TablerIcons.file_text);
  }

  Widget _buildPrivacySection(bool isArabic) {
    if (_remotePrivacy.isNotEmpty) {
      return _buildPolicyList(_remotePrivacy, TablerIcons.shield_check);
    }

    final items = isArabic
        ? [
            {'t': '١. البيانات التي نجمعها', 'c': 'نجمع معلومات الحساب الأساسية مثل الاسم، رقم الهاتف، والبريد الإلكتروني للتحقق من هوية المستخدم وتنفيذ الحجوزات.'},
            {'t': '٢. حماية وأمان البيانات', 'c': 'نطبق أعلى معايير التشفير والأمان لحماية بياناتك الشخصية ومعاملاتك المالية من أي وصول غير مصرح به.'},
            {'t': '٣. استخدام موقع الجهاز', 'c': 'نطلب إذن الموقع الجغرافي فقط لعرض أقرب صالات الألعاب والبطولات المحيطة بك وتحسين تجربة البحث.'},
            {'t': '٤. مشاركة البيانات مع الصالات', 'c': 'تشارك PlaySpot بيانات الحجز الأساسية (الاسم ورقم الهاتف) مع الصالة المحجوز لديها فقط لتأكيد حضورك وتنظيم الجلسة.'},
            {'t': '٥. حقوق المستخدم', 'c': 'يحق لك تعديل بياناتك الشخصية أو طلب حذف حسابك نهائياً في أي وقت من شاشة إعدادات الحساب.'},
          ]
        : [
            {'t': '1. Data Collection', 'c': 'We collect essential account details such as name, phone number, and email to process bookings and authenticate users.'},
            {'t': '2. Data Protection', 'c': 'We employ robust encryption and security standards to keep your personal and transaction data protected.'},
            {'t': '3. Location Access', 'c': 'Location permission is used solely to discover nearest gaming lounges and nearby tournaments.'},
            {'t': '4. Sharing with Lounges', 'c': 'We share minimal booking information (name & phone) with the selected lounge to prepare your gaming station.'},
            {'t': '5. Your Rights', 'c': 'You can edit your personal profile or request complete account deletion at any time via Account Settings.'},
          ];

    return _buildPolicyList(items, TablerIcons.shield_check);
  }

  Widget _buildRefundSection(bool isArabic) {
    if (_remoteRefund.isNotEmpty) {
      return _buildPolicyList(_remoteRefund, TablerIcons.rotate_clockwise);
    }

    final items = isArabic
        ? [
            {'t': '١. إلغاء الحجز المسبق', 'c': 'يمكنك إلغاء حجزك مجاناً وبشكل كامل قبل موعد الجلسة بساعتين (٢ ساعة) على الأقل من شاشة "حجوزاتي".'},
            {'t': '٢. استرداد الأموال', 'c': 'عند الإلغاء في الوقت المسموح، تُعاد قيمة الحجز فوراً كرصيد نقاط أو مكافآت بحسابك، أو لوسيلة الدفع الأصلية خلال ٣-٥ أيام عمل.'},
            {'t': '٣. الإلغاء المتأخر أو عدم الحضور', 'c': 'في حال الإلغاء قبل الموعد بأقل من ساعتين أو عدم الحضور، يتم خصم رسوم الإلغاء المحددة من الصالة بحد أقصى قيمة الساعة الأولى.'},
            {'t': '٤. تأخير الصالة أو المشاكل التقنية', 'c': 'إذا تعذر تجهيز الغرفة من قبل الصالة في الوقت المحجوز، يتم تعويضك بساعات إضافية أو استرداد كامل للقيمة فوراً.'},
          ]
        : [
            {'t': '1. Advance Cancellation', 'c': 'You can cancel your booking for free at least 2 hours before your scheduled session time from "My Bookings".'},
            {'t': '2. Refund Method', 'c': 'Eligible cancellations will be refunded to your in-app points balance instantly or back to original payment method in 3-5 business days.'},
            {'t': '3. Late Cancellation & No-Show', 'c': 'Cancellations made less than 2 hours in advance or no-shows may incur a cancellation fee equal to 1 hour rate.'},
            {'t': '4. Lounge Delays or Technical Issues', 'c': 'If the lounge fails to prepare your station on time, you will receive full refund or compensated bonus play time.'},
          ];

    return _buildPolicyList(items, TablerIcons.rotate_clockwise);
  }

  Widget _buildPolicyList(List<Map<String, String>> items, IconData icon) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: GlassContainer(
              borderRadius: 20,
              child: Padding(
                padding: EdgeInsets.all(18.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.neonBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(icon, color: AppColors.neonBlue, size: 20.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: AppText(
                            text: item['t'] ?? '',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    AppText(
                      text: item['c'] ?? '',
                      fontSize: 13.5.sp,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

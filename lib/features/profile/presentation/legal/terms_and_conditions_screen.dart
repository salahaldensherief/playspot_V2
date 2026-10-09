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
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, String>> _remoteTerms = [];
  List<Map<String, String>> _remotePrivacy = [];
  List<Map<String, String>> _remoteRefund = [];
  bool _policiesLoading = true;
  bool _policiesFailed = false;
  String? _policyLanguage;
  int _policyRequest = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context.locale.languageCode;
    if (_policyLanguage != language) {
      _policyLanguage = language;
      _loadPolicies();
    }
  }

  Future<void> _loadPolicies() async {
    final request = ++_policyRequest;
    setState(() {
      _policiesLoading = true;
      _policiesFailed = false;
      _remoteTerms = [];
      _remotePrivacy = [];
      _remoteRefund = [];
    });
    try {
      final lang = context.locale.languageCode;
      final policies = await sl<SupportRemoteDataSource>().getPolicies(lang);
      if (!mounted || request != _policyRequest) return;
      if (policies.isNotEmpty) {
        for (final policy in policies) {
          final type =
              (policy['policy_key'] ?? policy['type'] ?? policy['policy_type'])
                  ?.toString();
          final content =
              policy['content_$lang'] ??
              policy['content_ar'] ??
              policy['content_en'] ??
              policy['content'];

          List<Map<String, String>> parsedItems = [];
          if (content is String && content.trim().isNotEmpty) {
            parsedItems.add({
              't': policy['title']?.toString() ?? '',
              'c': content,
            });
          }
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
      if (mounted) setState(() => _policiesLoading = false);
    } catch (_) {
      if (mounted && request == _policyRequest) {
        setState(() {
          _policiesLoading = false;
          _policiesFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              labelStyle: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                Tab(text: AppStrings.termsTab.tr()),
                Tab(text: AppStrings.privacyTab.tr()),
                Tab(text: AppStrings.refundTab.tr()),
              ],
            ),
          ),
        ),
      ),
      body: _policiesLoading
          ? const Center(child: CircularProgressIndicator())
          : _policiesFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('supportDataLoadFailed'.tr()),
                  TextButton(
                    onPressed: _loadPolicies,
                    child: Text(AppStrings.retry.tr()),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPolicyList(_remoteTerms, TablerIcons.file_text),
                _buildPolicyList(_remotePrivacy, TablerIcons.shield_check),
                _buildPolicyList(_remoteRefund, TablerIcons.rotate_clockwise),
              ],
            ),
    );
  }

  Widget _buildPolicyList(List<Map<String, String>> items, IconData icon) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Text(
            'policyContentUnavailable'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
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
                          child: Icon(
                            icon,
                            color: AppColors.neonBlue,
                            size: 20.sp,
                          ),
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

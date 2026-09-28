import 'package:equatable/equatable.dart';

extension _StringHelper on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class LoyaltyMissionModel extends Equatable {
  final String id;
  final String code;
  final String title;
  final String titleAr;
  final String titleEn;
  final String description;
  final String descriptionAr;
  final String descriptionEn;
  final int pointsReward;
  final String? iconUrl;
  final int targetProgress;
  final int currentProgress;
  final bool isCompleted;

  const LoyaltyMissionModel({
    required this.id,
    this.code = '',
    required this.title,
    this.titleAr = '',
    this.titleEn = '',
    required this.description,
    this.descriptionAr = '',
    this.descriptionEn = '',
    required this.pointsReward,
    this.iconUrl,
    required this.targetProgress,
    required this.currentProgress,
    required this.isCompleted,
  });

  String getDisplayTitle(bool isArabic) {
    if (isArabic) {
      if (titleAr.isNotEmpty) return titleAr;
      if (title.isNotEmpty) return title;
      if (titleEn.isNotEmpty) return titleEn;
    } else {
      if (titleEn.isNotEmpty) return titleEn;
      if (title.isNotEmpty) return title;
      if (titleAr.isNotEmpty) return titleAr;
    }
    return title.ifEmpty('مهمة ولاء');
  }

  String getDisplayDescription(bool isArabic) {
    if (isArabic) {
      if (descriptionAr.isNotEmpty) return descriptionAr;
      if (description.isNotEmpty) return description;
      if (descriptionEn.isNotEmpty) return descriptionEn;
    } else {
      if (descriptionEn.isNotEmpty) return descriptionEn;
      if (description.isNotEmpty) return description;
      if (descriptionAr.isNotEmpty) return descriptionAr;
    }
    return description;
  }

  factory LoyaltyMissionModel.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? progressJson}) {
    final currentProg = progressJson != null
        ? ((progressJson['current_progress'] ?? progressJson['progress'] ?? progressJson['current_count'] ?? progressJson['current']) as num?)?.toInt() ?? 0
        : 0;
    final targetProg = ((json['target_progress'] ?? json['target_count'] ?? json['target'] ?? json['goal']) as num?)?.toInt() ?? 1;
    final completed = progressJson != null
        ? (progressJson['is_completed'] as bool? ?? (currentProg >= targetProg && targetProg > 0))
        : false;

    final rawCode = (json['code'] ?? json['mission_code'] ?? json['type'] ?? json['id'] ?? '')?.toString().toLowerCase() ?? '';

    String fallbackTitleAr = '';
    String fallbackTitleEn = '';
    String fallbackDescAr = '';
    String fallbackDescEn = '';

    if (rawCode.contains('two_completed') || rawCode.contains('regular') || rawCode.contains('9897752f')) {
      fallbackTitleAr = 'زائر منتظم';
      fallbackTitleEn = 'Regular Visitor';
      fallbackDescAr = 'أكمل حجزين في الصالات واحصل على مكافأة إضافية';
      fallbackDescEn = 'Complete 2 bookings to earn bonus points';
    } else if (rawCode.contains('off_peak') || rawCode.contains('quiet') || rawCode.contains('8de14986')) {
      fallbackTitleAr = 'بطل الأوقات الهادئة';
      fallbackTitleEn = 'Off-Peak Hero';
      fallbackDescAr = 'احجز في الأوقات الهادئة للحصول على نقاط مضاعفة';
      fallbackDescEn = 'Book during off-peak hours for extra points';
    } else if (rawCode.contains('first') || rawCode.contains('welcome') || rawCode.contains('ad857ac2')) {
      fallbackTitleAr = 'بداية المغامرة';
      fallbackTitleEn = 'First Booking';
      fallbackDescAr = 'قم بإنشاء أول حجز لك عبر التطبيق';
      fallbackDescEn = 'Complete your first booking on PlaySpot';
    } else if (rawCode.contains('profile') || rawCode.contains('3c19abf8')) {
      fallbackTitleAr = 'مستكشف الملف الشخصي';
      fallbackTitleEn = 'Profile Pioneer';
      fallbackDescAr = 'أكمل بيانات حسابك الشخصي وحدث موقعك';
      fallbackDescEn = 'Complete your profile details and location';
    } else {
      fallbackTitleAr = 'مهمة ولاء جديدة';
      fallbackTitleEn = 'Loyalty Mission';
      fallbackDescAr = 'أكمل المهمة للحصول على نقاط مكافأة';
      fallbackDescEn = 'Complete this mission to earn bonus points';
    }

    final rawTitleAr = json['title_ar']?.toString() ?? json['name_ar']?.toString() ?? '';
    final rawTitleEn = json['title_en']?.toString() ?? json['name_en']?.toString() ?? '';
    final rawTitle = json['title']?.toString() ?? json['name']?.toString() ?? json['mission_name']?.toString() ?? json['label']?.toString() ?? '';

    final parsedTitleAr = rawTitleAr.ifEmpty(rawTitle.isNotEmpty ? rawTitle : fallbackTitleAr);
    final parsedTitleEn = rawTitleEn.ifEmpty(rawTitle.isNotEmpty ? rawTitle : fallbackTitleEn);
    final parsedTitle = rawTitle.ifEmpty(parsedTitleAr.isNotEmpty ? parsedTitleAr : fallbackTitleAr);

    final rawDescAr = json['description_ar']?.toString() ?? json['desc_ar']?.toString() ?? '';
    final rawDescEn = json['description_en']?.toString() ?? json['desc_en']?.toString() ?? '';
    final rawDesc = json['description']?.toString() ?? json['desc']?.toString() ?? json['details']?.toString() ?? '';

    final parsedDescAr = rawDescAr.ifEmpty(rawDesc.isNotEmpty ? rawDesc : fallbackDescAr);
    final parsedDescEn = rawDescEn.ifEmpty(rawDesc.isNotEmpty ? rawDesc : fallbackDescEn);
    final parsedDesc = rawDesc.ifEmpty(parsedDescAr.isNotEmpty ? parsedDescAr : fallbackDescAr);

    return LoyaltyMissionModel(
      id: json['id']?.toString() ?? '',
      code: rawCode,
      title: parsedTitle,
      titleAr: parsedTitleAr,
      titleEn: parsedTitleEn,
      description: parsedDesc,
      descriptionAr: parsedDescAr,
      descriptionEn: parsedDescEn,
      pointsReward: ((json['points_reward'] ?? json['reward_points'] ?? json['points'] ?? json['reward']) as num?)?.toInt() ?? 0,
      iconUrl: json['icon_url']?.toString(),
      targetProgress: targetProg,
      currentProgress: currentProg,
      isCompleted: completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'title_ar': titleAr,
        'title_en': titleEn,
        'description': description,
        'description_ar': descriptionAr,
        'description_en': descriptionEn,
        'points_reward': pointsReward,
        'icon_url': iconUrl,
        'target_progress': targetProgress,
        'current_progress': currentProgress,
        'is_completed': isCompleted,
      };

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        titleAr,
        titleEn,
        description,
        descriptionAr,
        descriptionEn,
        pointsReward,
        iconUrl,
        targetProgress,
        currentProgress,
        isCompleted,
      ];
}

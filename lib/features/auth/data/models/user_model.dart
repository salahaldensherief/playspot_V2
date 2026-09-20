import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  final bool isNewUser;
  final bool isRequiresOtp;

  const UserModel({
    required super.id,
    super.name,
    super.email,
    super.phone,
    super.avatarUrl,
    super.referralCode,
    super.cityId,
    super.cityNameAr,
    super.cityNameEn,
    super.role = 'user',
    super.isBanned,
    super.bannedReason,
    super.createdAt,
    this.isNewUser = false,
    this.isRequiresOtp = false,
  });

  /// Normalizes database role aliases to officially recognized role keys
  static String normalizeRole(String? rawRole) {
    if (rawRole == null || rawRole.trim().isEmpty) return 'user';
    final role = rawRole.toLowerCase().trim();
    switch (role) {
      case 'owner':
      case 'lounge_owner':
        return 'owner';
      case 'manager':
      case 'lounge_admin':
      case 'admin':
        return 'manager';
      case 'cashier':
        return 'cashier';
      case 'staff':
        return 'staff';
      case 'super_admin':
        return 'super_admin';
      case 'user':
      default:
        return 'user';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final cityData = json['cities'] is Map<String, dynamic>
        ? json['cities'] as Map<String, dynamic>
        : null;
    return UserModel(
      id: json['id'] as String,
      name: json['full_name'] as String? ?? json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      referralCode: json['referral_code'] as String?,
      cityId: json['city_id'] as String?,
      cityNameAr: cityData?['name_ar'] as String? ?? cityData?['name'] as String?,
      cityNameEn: cityData?['name_en'] as String? ?? cityData?['name'] as String?,
      role: normalizeRole(json['role'] as String?),
      isBanned: json['is_banned'] as bool? ?? false,
      bannedReason: json['banned_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  factory UserModel.fromSupabaseUser(
      Map<String, dynamic> supabaseUser, {
        bool isNewUser = false,
      }) {
    final metadata =
        supabaseUser['user_metadata'] as Map<String, dynamic>? ?? {};
    final rawRole = metadata['role'] as String? ?? supabaseUser['role'] as String?;

    final phoneVal = (supabaseUser['phone'] as String?)?.trim();
    final metadataPhone = (metadata['phone'] as String?)?.trim();
    final finalPhone = (phoneVal != null && phoneVal.isNotEmpty)
        ? phoneVal
        : (metadataPhone != null && metadataPhone.isNotEmpty ? metadataPhone : null);

    return UserModel(
      id: supabaseUser['id'] as String,
      name: metadata['full_name'] as String? ?? metadata['name'] as String?,
      email: supabaseUser['email'] as String?,
      phone: finalPhone,
      avatarUrl:
      metadata['avatar_url'] as String? ?? metadata['picture'] as String?,
      referralCode: metadata['referral_code'] as String?,
      cityId: metadata['city_id'] as String?,
      cityNameAr: metadata['city_name_ar'] as String?,
      cityNameEn: metadata['city_name_en'] as String?,
      role: normalizeRole(rawRole),
      isBanned: (metadata['is_banned'] as bool?) ?? (supabaseUser['is_banned'] as bool?) ?? false,
      bannedReason: (metadata['banned_reason'] as String?) ?? (supabaseUser['banned_reason'] as String?),
      isNewUser: isNewUser,
      createdAt: supabaseUser['created_at'] != null
          ? DateTime.parse(supabaseUser['created_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => super.props..addAll([isNewUser, isRequiresOtp]);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'referral_code': referralCode,
      'city_id': cityId,
      'city_name_ar': cityNameAr,
      'city_name_en': cityNameEn,
      'role': role,
      'is_banned': isBanned,
      if (bannedReason != null) 'banned_reason': bannedReason,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? referralCode,
    String? cityId,
    String? cityNameAr,
    String? cityNameEn,
    String? role,
    bool? isBanned,
    String? bannedReason,
    bool? isNewUser,
    bool? isRequiresOtp,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      referralCode: referralCode ?? this.referralCode,
      cityId: cityId ?? this.cityId,
      cityNameAr: cityNameAr ?? this.cityNameAr,
      cityNameEn: cityNameEn ?? this.cityNameEn,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
      isNewUser: isNewUser ?? this.isNewUser,
      isRequiresOtp: isRequiresOtp ?? this.isRequiresOtp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
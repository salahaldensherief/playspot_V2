import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? referralCode;
  final String? cityId;
  final String? cityNameAr;
  final String? cityNameEn;
  final String role;
  final bool isBanned;
  final String? bannedReason;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.referralCode,
    this.cityId,
    this.cityNameAr,
    this.cityNameEn,
    this.role = 'user',
    this.isBanned = false,
    this.bannedReason,
    this.createdAt,
  });

  String? getCityName(bool isArabic) {
    return isArabic ? (cityNameAr ?? cityNameEn) : (cityNameEn ?? cityNameAr);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        avatarUrl,
        referralCode,
        cityId,
        cityNameAr,
        cityNameEn,
        role,
        isBanned,
        bannedReason,
        createdAt,
      ];
}
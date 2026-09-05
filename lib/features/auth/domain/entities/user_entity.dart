import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? referralCode;
  final bool isBanned;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.referralCode,
    this.isBanned = false,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, email, phone, avatarUrl, referralCode, isBanned, createdAt];
}
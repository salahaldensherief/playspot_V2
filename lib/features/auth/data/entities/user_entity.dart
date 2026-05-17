class UserEntity {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool isBanned;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.isBanned = false,
    this.createdAt,
  });
}
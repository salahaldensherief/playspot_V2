import '../entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.name,
    super.email,
    super.phone,
    super.avatarUrl,
    super.isBanned,
    super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  factory UserModel.fromSupabaseUser(Map<String, dynamic> supabaseUser) {
    final metadata = supabaseUser['user_metadata'] as Map<String, dynamic>? ?? {};
    return UserModel(
      id: supabaseUser['id'] as String,
      name: metadata['full_name'] as String? ?? metadata['name'] as String?,
      email: supabaseUser['email'] as String?,
      phone: supabaseUser['phone'] as String?,
      avatarUrl: metadata['avatar_url'] as String? ?? metadata['picture'] as String?,
      isBanned: false,
      createdAt: supabaseUser['created_at'] != null
          ? DateTime.parse(supabaseUser['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_banned': isBanned,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? isBanned,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
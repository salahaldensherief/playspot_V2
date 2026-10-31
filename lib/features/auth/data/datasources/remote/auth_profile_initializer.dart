import 'package:supabase_flutter/supabase_flutter.dart';

/// Creates a missing profile without replacing customer-managed profile data.
class AuthProfileInitializer {
  const AuthProfileInitializer(this._client);

  final SupabaseClient _client;

  Future<bool> ensureProfile(User user) async {
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return false;

    final metadata = user.userMetadata ?? {};
    final inserted = await _client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'email': user.email,
            'role': 'user',
            'full_name':
                metadata['full_name'] ??
                metadata['name'] ??
                user.email?.split('@').first ??
                'User',
            'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        )
        .select('id');
    return inserted.isNotEmpty;
  }
}

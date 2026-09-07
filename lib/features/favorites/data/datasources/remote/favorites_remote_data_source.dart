import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../home/data/models/lounge_model.dart';

abstract class FavoritesRemoteDataSource {
  Future<List<LoungeModel>> getFavorites();
  Future<void> addFavorite(String loungeId);
  Future<void> removeFavorite(String loungeId);
  Future<List<String>> getFavoriteIds();
}

class FavoritesRemoteDataSourceImpl implements FavoritesRemoteDataSource {
  final SupabaseClient _client;

  FavoritesRemoteDataSourceImpl(this._client);

  String? get _currentUserId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) return null;
    return uid;
  }

  @override
  Future<List<LoungeModel>> getFavorites() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('favorites')
          .select('*, lounges(*)')
          .eq('user_id', userId);

      final List<LoungeModel> lounges = [];
      for (final e in (response as List)) {
        if (e['lounges'] != null) {
          final loungeData = e['lounges'];
          if (loungeData is List && loungeData.isNotEmpty) {
            lounges.add(LoungeModel.fromJson(loungeData.first));
          } else if (loungeData is Map) {
            lounges.add(
                LoungeModel.fromJson(Map<String, dynamic>.from(loungeData)));
          }
        }
      }
      return lounges;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addFavorite(String loungeId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw const AuthException('User is not authenticated');
      }

      await _client.from('favorites').upsert({
        'user_id': userId,
        'lounge_id': loungeId,
      }, onConflict: 'user_id,lounge_id');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> removeFavorite(String loungeId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw Exception('User is not authenticated');
      }

      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('lounge_id', loungeId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<String>> getFavoriteIds() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('favorites')
          .select('lounge_id')
          .eq('user_id', userId);

      return (response as List).map((e) => e['lounge_id'].toString()).toList();
    } catch (e) {
      rethrow;
    }
  }
}

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

  String get _userId => _client.auth.currentUser?.id ?? '';

  @override
  Future<List<LoungeModel>> getFavorites() async {
    try {
      final response = await _client
          .from('favorites')
          .select('*, lounges(*)')
          .eq('user_id', _userId);

      if (response == null) return [];

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
      await _client.from('favorites').insert({
        'user_id': _userId,
        'lounge_id': loungeId,
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> removeFavorite(String loungeId) async {
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', _userId)
          .eq('lounge_id', loungeId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<String>> getFavoriteIds() async {
    try {
      final response = await _client
          .from('favorites')
          .select('lounge_id')
          .eq('user_id', _userId);

      return (response as List).map((e) => e['lounge_id'].toString()).toList();
    } catch (e) {
      rethrow;
    }
  }
}

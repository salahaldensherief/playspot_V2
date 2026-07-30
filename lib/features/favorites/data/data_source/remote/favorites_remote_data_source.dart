import 'dart:developer';
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
    log("FAVORITES_REMOTE: Getting favorites for user: $_userId");
    try {
      final response = await _client
          .from('favorites')
          .select('*, lounges(*)')
          .eq('user_id', _userId);

      log("FAVORITES_REMOTE: Raw response: $response");

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
      log("FAVORITES_REMOTE: Parsed ${lounges.length} lounges");
      return lounges;
    } catch (e, stack) {
      log("FAVORITES_REMOTE_ERROR: $e", stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> addFavorite(String loungeId) async {
    log("FAVORITES_REMOTE: Adding favorite: $loungeId for user: $_userId");
    try {
      await _client.from('favorites').insert({
        'user_id': _userId,
        'lounge_id': loungeId,
      });
      log("FAVORITES_REMOTE: Added successfully");
    } catch (e) {
      log("FAVORITES_REMOTE_ERROR (add): $e");
      rethrow;
    }
  }

  @override
  Future<void> removeFavorite(String loungeId) async {
    log("FAVORITES_REMOTE: Removing favorite: $loungeId for user: $_userId");
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', _userId)
          .eq('lounge_id', loungeId);
      log("FAVORITES_REMOTE: Removed successfully");
    } catch (e) {
      log("FAVORITES_REMOTE_ERROR (remove): $e");
      rethrow;
    }
  }

  @override
  Future<List<String>> getFavoriteIds() async {
    log("FAVORITES_REMOTE: Getting favorite IDs for user: $_userId");
    try {
      final response = await _client
          .from('favorites')
          .select('lounge_id')
          .eq('user_id', _userId);

      log("FAVORITES_REMOTE: IDs response: $response");
      final ids =
          (response as List).map((e) => e['lounge_id'].toString()).toList();
      log("FAVORITES_REMOTE: Found ${ids.length} IDs");
      return ids;
    } catch (e) {
      log("FAVORITES_REMOTE_ERROR (ids): $e");
      rethrow;
    }
  }
}

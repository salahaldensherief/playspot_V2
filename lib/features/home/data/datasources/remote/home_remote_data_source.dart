import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../models/promo_model.dart';
import '../../models/category_model.dart';
import '../../models/home_params.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges(GetLoungesParams params);
  Future<List<Map<String, dynamic>>> getAvailableCities();
  Future<List<PromoModel>> getPromotions({String? loungeId});
  Future<List<CategoryModel>> getCategories();
  Future<int> getUserPoints(String userId);
  Future<LoungeModel?> getLoungeById(String id);
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;
  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<LoungeModel?> getLoungeById(String id) async {
    try {
      final response = await _client
          .from('lounges')
          .select()
          .eq('id', id)
          .eq('is_active', true)
          .neq('status', 'deleted')
          .maybeSingle();
      if (response == null) return null;
      return LoungeModel.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> getUserPoints(String userId) async {
    try {
      final response = await _client.rpc('get_user_points_balance', params: {
        'p_user_id': userId,
      });
      return response as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<LoungeModel>> getLounges(GetLoungesParams params) async {
    try {
      AppLogger.info("FETCHING_LOUNGES directly from lounges table");
      dynamic query = _client
          .from('lounges')
          .select()
          .eq('is_active', true)
          .neq('status', 'deleted');

      if (params.city != null && params.city!.isNotEmpty) {
        query = query.eq('city', params.city!);
      }

      if (params.sortType == 'top_rated') {
        query = query.order('rating', ascending: false);
      } else {
        query = query.order('is_open', ascending: false).order('rating', ascending: false);
      }

      final response = await query.range(params.offset, params.offset + params.limit - 1);
      final List lounges = response as List;
      AppLogger.info("LOUNGES_DIRECT_SELECT_COUNT: ${lounges.length}");

      return lounges.map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      AppLogger.warning("FETCH_LOUNGES_DIRECT_ERROR: $e, falling back to RPC get_nearby_lounges");
      try {
        final response = await _client.rpc('get_nearby_lounges', params: {
          'user_lat': params.lat ?? 30.0444,
          'user_lon': params.lng ?? 31.2357,
        });

        final List lounges = response as List;
        return lounges.map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (fallbackError) {
        AppLogger.error("FETCH_LOUNGES_CRITICAL_ERROR: $fallbackError");
        return [];
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableCities() async {
    final res = await _client.rpc('get_available_cities');
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<PromoModel>> getPromotions({String? loungeId}) async {
    try {
      AppLogger.info("FETCHING_PROMOTIONS: loungeId=$loungeId");

      final response = await _client.rpc(
        'get_active_promos',
        params: {'p_lounge_id': loungeId},
      );

      final List data = response as List;
      AppLogger.info("PROMOTIONS_RAW_DATA_COUNT: ${data.length}");

      final promos = data.map((e) {
        try {
          return PromoModel.fromJson(Map<String, dynamic>.from(e));
        } catch (e) {
          AppLogger.warning("PROMO_PARSING_ERROR: $e");
          return null;
        }
      }).whereType<PromoModel>().toList();

      AppLogger.info("PROMOTIONS_PARSED_SUCCESSFULLY: ${promos.length}");
      return promos;
    } catch (e) {
      AppLogger.error("GET_PROMOTIONS_CRITICAL_ERROR: $e");
      try {
        var query = _client.from('promotions').select().eq('is_active', true).gt('expires_at', DateTime.now().toIso8601String());
        if (loungeId != null && loungeId.isNotEmpty) {
          query = query.eq('lounge_id', loungeId);
        }
        final fallbackRes = await query;
        final List data = fallbackRes as List;
        return data.map((e) {
          try {
            return PromoModel.fromJson(Map<String, dynamic>.from(e));
          } catch (_) {
            return null;
          }
        }).whereType<PromoModel>().toList();
      } catch (fallbackError) {
        AppLogger.error("GET_PROMOTIONS_FALLBACK_ERROR: $fallbackError");
        return [];
      }
    }
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final res = await _client.from('categories').select().order('id');
    return (res as List).map((e) => CategoryModel.fromJson(e)).toList();
  }
}

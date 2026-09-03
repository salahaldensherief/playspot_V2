import 'dart:developer' as dev;
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
      final response = await _client.from('lounges').select().eq('id', id).maybeSingle();
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
      dev.log("FETCHING_LOUNGES: city=${params.city}, categories=${params.categoryIds}, sort=${params.sortType}");
      
      // We pass categoryIds as simple List<String> which matches text[] in SQL
      final response = await _client.rpc('get_smart_filtered_lounges', params: {
        'user_lat': params.lat ?? 30.0444,
        'user_lng': params.lng ?? 31.2357,
        'p_city_name': (params.city != null && params.city!.isNotEmpty) ? params.city : null,
        'p_category_ids': (params.categoryIds != null && params.categoryIds!.isNotEmpty) ? params.categoryIds : null,
        'p_sort_type': params.sortType,
        'p_limit': params.limit,
        'p_offset': params.offset,
      });

      final List lounges = response as List;
      dev.log("RPC_RESULTS_COUNT: ${lounges.length}");
      
      return lounges.map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      dev.log("FETCH_LOUNGES_CRITICAL_ERROR: $e");
      // Prevent infinite loops or misleading UI by only falling back on empty initial loads
      if ((params.categoryIds == null || params.categoryIds!.isEmpty) && params.offset == 0) {
        final fallback = await _client.from('lounges')
            .select()
            .range(params.offset, params.offset + params.limit - 1);
        return (fallback as List).map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      return [];
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
      dev.log("FETCHING_PROMOTIONS: loungeId=$loungeId");

      final response = await _client.rpc(
        'get_active_promos',
        params: {'p_lounge_id': loungeId},
      );

      final List data = response as List;
      dev.log("PROMOTIONS_RAW_DATA_COUNT: ${data.length}");

      final promos = data.map((e) {
        try {
          return PromoModel.fromJson(Map<String, dynamic>.from(e));
        } catch (e) {
          dev.log("PROMO_PARSING_ERROR: $e");
          return null;
        }
      }).whereType<PromoModel>().toList();

      dev.log("PROMOTIONS_PARSED_SUCCESSFULLY: ${promos.length}");
      return promos;
    } catch (e) {
      dev.log("GET_PROMOTIONS_CRITICAL_ERROR: $e");
      try {
        var query = _client.from('promotions').select();
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
        dev.log("GET_PROMOTIONS_FALLBACK_ERROR: $fallbackError");
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

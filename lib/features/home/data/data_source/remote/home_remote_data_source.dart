import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../models/promo_model.dart';
import '../../models/category_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges({
    double? lat,
    double? lng,
    String? city,
    List<String>? categoryIds,
    String sortType = 'nearest',
    int pLimit = 20,
    int pOffset = 0,
  });
  Future<List<Map<String, dynamic>>> getAvailableCities();
  Future<List<PromoModel>> getPromotions();
  Future<List<CategoryModel>> getCategories();
  Future<int> getUserPoints(String userId);
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;
  HomeRemoteDataSourceImpl(this._client);

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
  Future<List<LoungeModel>> getLounges({
    double? lat,
    double? lng,
    String? city,
    List<String>? categoryIds,
    String sortType = 'nearest',
    int pLimit = 20,
    int pOffset = 0,
  }) async {
    try {
      dev.log("FETCHING_LOUNGES: city=$city, categories=$categoryIds, sort=$sortType");
      
      // We pass categoryIds as simple List<String> which matches text[] in SQL
      final response = await _client.rpc('get_smart_filtered_lounges', params: {
        'user_lat': lat ?? 30.0444,
        'user_lng': lng ?? 31.2357,
        'p_city_name': (city != null && city.isNotEmpty) ? city : null,
        'p_category_ids': (categoryIds != null && categoryIds.isNotEmpty) ? categoryIds : null,
        'p_sort_type': sortType,
        'p_limit': pLimit,
        'p_offset': pOffset,
      });

      final List lounges = response as List;
      dev.log("RPC_RESULTS_COUNT: ${lounges.length}");
      
      return lounges.map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      dev.log("FETCH_LOUNGES_CRITICAL_ERROR: $e");
      // Prevent infinite loops or misleading UI by only falling back on empty initial loads
      if ((categoryIds == null || categoryIds.isEmpty) && pOffset == 0) {
        final fallback = await _client.from('lounges')
            .select()
            .range(pOffset, pOffset + pLimit - 1);
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
  Future<List<PromoModel>> getPromotions() async {
    final res = await _client.from('promotions').select();
    return (res as List).map((e) => PromoModel.fromJson(e)).toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final res = await _client.from('categories').select().order('id');
    return (res as List).map((e) => CategoryModel.fromJson(e)).toList();
  }
}

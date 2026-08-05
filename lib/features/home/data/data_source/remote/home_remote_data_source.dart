import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../models/promo_model.dart';
import '../../models/category_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges({double? lat, double? lng, String? city, List<String>? categoryIds});
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
  Future<List<LoungeModel>> getLounges({double? lat, double? lng, String? city, List<String>? categoryIds}) async {
    try {
      dev.log("FETCHING_LOUNGES: city=$city, lat=$lat, lng=$lng, categories=$categoryIds");
      
      final response = await _client.rpc('get_smart_filtered_lounges', params: {
        'user_lat': lat,
        'user_lng': lng,
        'city_name': (city != null && city.isNotEmpty) ? city : null,
        'category_ids': (categoryIds != null && categoryIds.isNotEmpty) ? categoryIds : null,
      });

      List lounges = response as List;
      dev.log("RPC_RESULTS_COUNT: ${lounges.length}");
      
      // If a city is explicitly selected but RPC returned nothing (could be distance limit issue)
      if (lounges.isEmpty && city != null && city.isNotEmpty) {
        dev.log("FALLBACK: Fetching lounges directly for city: $city");
        final fallback = await _client.from('lounges').select().eq('city', city);
        lounges = fallback as List;
      }
      
      // General fallback if everything is empty
      if (lounges.isEmpty && (city == null || city.isEmpty)) {
        final all = await _client.from('lounges').select();
        lounges = all as List;
      }

      return lounges.map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      dev.log("FETCH_LOUNGES_CRITICAL_ERROR: $e");
      final fallback = await _client.from('lounges').select();
      return (fallback as List).map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
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

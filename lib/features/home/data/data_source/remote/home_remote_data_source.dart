import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../models/promo_model.dart';
import '../../models/category_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges({double? lat, double? lng, String? city});
  Future<List<Map<String, dynamic>>> getAvailableCities();
  Future<List<PromoModel>> getPromotions();
  Future<List<CategoryModel>> getCategories();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;
  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<List<LoungeModel>> getLounges({double? lat, double? lng, String? city}) async {
    try {
      final response = await _client.rpc('get_smart_filtered_lounges', params: {
        'user_lat': lat,
        'user_lng': lng,
        'city_name': (city != null && city.isNotEmpty) ? city : null,
      });

      List lounges = response as List;
      
      if (lounges.isEmpty) {
        final fallback = await _client.from('lounges').select();
        lounges = fallback as List;
      }

      return lounges.map((e) => LoungeModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
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

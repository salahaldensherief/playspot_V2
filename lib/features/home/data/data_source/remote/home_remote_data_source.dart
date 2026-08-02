import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges({double? lat, double? lng, String? city});
  Future<List<Map<String, dynamic>>> getAvailableCities();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<List<LoungeModel>> getLounges({double? lat, double? lng, String? city}) async {
    try {
      final response;

      if (city != null && city.isNotEmpty) {
        // Fetch by city filter
        response = await _client.from('lounges').select().eq('city', city);
      } else if (lat != null && lng != null) {
        // Fetch by nearby location
        response = await _client.rpc('get_nearby_lounges', params: {
          'user_lat': lat,
          'user_lng': lng,
          'max_distance_km': 20000.0,
        });
      } else {
        // Default fetch
        response = await _client.from('lounges').select();
      }

      return (response as List).map((e) {
        return LoungeModel.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableCities() async {
    try {
      final response = await _client.rpc('get_available_cities');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }
}

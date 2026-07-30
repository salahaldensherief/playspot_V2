import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges({double? lat, double? lng});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<List<LoungeModel>> getLounges({double? lat, double? lng}) async {
    final response;
    
    if (lat != null && lng != null) {
      // Call the RPC function created for geospatial sorting
      response = await _client.rpc('get_nearby_lounges', params: {
        'user_lat': lat,
        'user_lng': lng,
      });
    } else {
      // Fallback to normal fetch if location is not available
      response = await _client.from('lounges').select();
    }

    return (response as List).map((e) {
      // Map dist_meters from RPC to the distance field in our model if present
      if (e['dist_meters'] != null) {
        e['distance'] = (e['dist_meters'] as num) / 1000.0; // Convert to KM
      }
      return LoungeModel.fromJson(e);
    }).toList();
  }
}

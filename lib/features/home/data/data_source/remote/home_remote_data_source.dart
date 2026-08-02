import 'dart:developer';
import 'dart:developer';
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
    try {
      final response;

      if (lat != null && lng != null) {
        log("HOME_REMOTE: Calling get_nearby_lounges with lat: $lat, lng: $lng");
        response = await _client.rpc('get_nearby_lounges', params: {
          'user_lat': lat,
          'user_lng': lng,
          'max_distance_km': 20000.0,
        });
      } else {
        log("HOME_REMOTE: Calling lounges select");
        response = await _client.from('lounges').select();
      }

      log("HOME_REMOTE: Response received. Count: ${(response as List).length}");

      return (response).map((e) {
        try {
          return LoungeModel.fromJson(Map<String, dynamic>.from(e));
        } catch (e, stack) {
          log("HOME_REMOTE: Item parsing error: $e", stackTrace: stack);
          rethrow;
        }
      }).toList();
    } catch (e, stack) {
      log("HOME_REMOTE_ERROR: $e", stackTrace: stack);
      rethrow;
    }
  }
}

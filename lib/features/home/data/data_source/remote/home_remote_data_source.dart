import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../../../lounge_details/data/room_model.dart';
import '../../../../lounge_details/data/extra_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges();
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId);
  Future<List<ExtraModel>> getExtras();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<List<LoungeModel>> getLounges() async {
    final response = await _client
        .from('lounges')
        .select();

    print("RAW DATA: $response");

    return (response as List)
        .map((e) => LoungeModel.fromJson(e))
        .toList();
  }
  // Future<List<LoungeModel>> getLounges() async {
  //
  //   final response = await _client.from('lounges').select();
  //   print(response);
  //   return (response as List).map((e) => LoungeModel.fromJson(e)).toList();
  //
  // }

  @override
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('lounge_id', loungeId);
    print("ROOM FILTER LOUNGE ID => '$loungeId'");
    print("ROOMS RAW => $response");

    return (response as List).map((e) => RoomModel.fromJson(e)).toList();
  }

  @override
  Future<List<ExtraModel>> getExtras() async {
    final response = await _client.from('extras').select();
    return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
  }
}

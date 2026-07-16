import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/extra_model.dart';
import '../../models/room_model.dart';

abstract class LoungeDetailsRemoteDataSource {
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId);
  Future<List<ExtraModel>> getExtras();
}

class LoungeDetailsRemoteDataSourceImpl implements LoungeDetailsRemoteDataSource {
  final SupabaseClient _client;

  LoungeDetailsRemoteDataSourceImpl(this._client);

  @override
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId) async {
    final response = await _client
        .from('rooms_with_activities')
        .select()
        .eq('lounge_id', loungeId);
    
    return (response as List).map((e) => RoomModel.fromJson(e)).toList();
  }

  @override
  Future<List<ExtraModel>> getExtras() async {
    final response = await _client.from('extras').select();
    return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
  }
}

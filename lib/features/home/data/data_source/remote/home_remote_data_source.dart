import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<List<LoungeModel>> getLounges() async {
    final response = await _client
        .from('lounges')
        .select();

    return (response as List)
        .map((e) => LoungeModel.fromJson(e))
        .toList();
  }
}

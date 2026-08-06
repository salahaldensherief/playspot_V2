import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../home/data/models/category_model.dart';
import '../../models/extra_model.dart';
import '../../models/room_model.dart';
import '../../models/review_model.dart';

abstract class LoungeDetailsRemoteDataSource {
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId, {String? categoryId});
  Future<List<ExtraModel>> getExtras(String loungeId);
  Future<List<CategoryModel>> getLoungeCategories(String loungeId);
  Future<List<ReviewModel>> getLoungeReviews(String loungeId);
}

class LoungeDetailsRemoteDataSourceImpl implements LoungeDetailsRemoteDataSource {
  final SupabaseClient _client;

  LoungeDetailsRemoteDataSourceImpl(this._client);

  @override
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId, {String? categoryId}) async {
    final bool hasFilter = categoryId != null && categoryId.isNotEmpty && categoryId.toLowerCase() != 'all';
    final joinType = hasFilter ? 'room_categories!inner' : 'room_categories';
    
    var query = _client
        .from('rooms')
        .select('*, space_types(name, label), $joinType(category_id, categories(name_en))')
        .eq('lounge_id', loungeId)
        .eq('is_available', true);
    
    if (hasFilter) {
      query = query.eq('room_categories.category_id', categoryId);
    }
    
    final response = await query;
    return (response as List).map((e) => RoomModel.fromJson(e)).toList();
  }

  @override
  Future<List<ExtraModel>> getExtras(String loungeId) async {
    final response = await _client
        .from('extras')
        .select()
        .eq('lounge_id', loungeId)
        .eq('is_available', true);
    return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
  }

  @override
  Future<List<CategoryModel>> getLoungeCategories(String loungeId) async {
    final response = await _client.rpc('get_lounge_categories', params: {
      'p_lounge_id': loungeId,
    });
    return (response as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  @override
  Future<List<ReviewModel>> getLoungeReviews(String loungeId) async {
    try {
      // Trying with 'profiles' as it's common in Supabase, if it fails, the catch block will handle it
      final response = await _client
          .from('reviews')
          .select('*, profiles:user_id(name, avatar_url)')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      return (response as List).map((e) {
        // Map 'profiles' back to 'users' for the model compatibility
        final data = Map<String, dynamic>.from(e);
        if (data.containsKey('profiles')) {
          data['users'] = data['profiles'];
        }
        return ReviewModel.fromJson(data);
      }).toList();
    } catch (e) {
      // Fallback: fetch reviews without user details to avoid crashing the screen
      final response = await _client
          .from('reviews')
          .select('*')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => ReviewModel.fromJson(e)).toList();
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../home/data/models/category_model.dart';
import '../../models/extra_model.dart';
import '../../models/room_model.dart';
import '../../models/review_model.dart';

abstract class LoungeDetailsRemoteDataSource {
  Future<List<RoomModel>> getRoomsByLoungeId(
    String loungeId, {
    String? categoryId,
  });
  Future<List<ExtraModel>> getExtras(String loungeId);
  Future<List<CategoryModel>> getLoungeCategories(String loungeId);
  Future<List<ReviewModel>> getLoungeReviews(String loungeId);
  Future<RoomModel?> getRoomById(String roomId);
}

class LoungeDetailsRemoteDataSourceImpl
    implements LoungeDetailsRemoteDataSource {
  final SupabaseClient _client;

  LoungeDetailsRemoteDataSourceImpl(this._client);

  @override
  Future<RoomModel?> getRoomById(String roomId) async {
    try {
      final response = await _client
          .from('rooms_detailed_view')
          .select(
            '*, promotions:promotions!room_id(id, tag_ar, tag_en, is_active, expires_at, discount_value, discount_type)',
          )
          .eq('id', roomId)
          .maybeSingle();

      if (response != null) return RoomModel.fromJson(response);

      // Fallback
      final fallbackResponse = await _client
          .from('rooms')
          .select(
            '*, space_types(name, label), room_categories(category_id, categories(name_en)), promotions:promotions!room_id(id, tag_ar, tag_en, is_active, expires_at, discount_value, discount_type)',
          )
          .eq('id', roomId)
          .maybeSingle();

      if (fallbackResponse != null) return RoomModel.fromJson(fallbackResponse);
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<RoomModel>> getRoomsByLoungeId(
    String loungeId, {
    String? categoryId,
  }) async {
    final bool hasFilter =
        categoryId != null &&
        categoryId.isNotEmpty &&
        categoryId.toLowerCase() != 'all';

    // We try to use rooms_detailed_view for better space type filtering
    var query = _client
        .from('rooms_detailed_view')
        .select(
          '*, space_types:space_type_id(name, label), promotions:promotions!room_id(id, tag_ar, tag_en, is_active, expires_at, discount_value, discount_type)',
        )
        .eq('lounge_id', loungeId)
        .eq('is_available', true); // هذا هو عمود زر الـ Online Toggle الفعلي

    if (hasFilter) {
      query = query.contains('category_ids', [categoryId]);
    }

    try {
      final response = await query;
      return (response as List).map((e) => RoomModel.fromJson(e)).toList();
    } catch (e) {
      // Fallback to rooms table if view doesn't exist or fails
      final joinType = hasFilter ? 'room_categories!inner' : 'room_categories';
      var fallbackQuery = _client
          .from('rooms')
          .select(
            '*, space_types(name, label), $joinType(category_id, categories(name_en)), promotions:promotions!room_id(id, tag_ar, tag_en, is_active, expires_at, discount_value, discount_type)',
          )
          .eq('lounge_id', loungeId)
          .eq('is_available', true);

      if (hasFilter) {
        fallbackQuery = fallbackQuery.eq(
          'room_categories.category_id',
          categoryId,
        );
      }

      final response = await fallbackQuery;
      return (response as List).map((e) => RoomModel.fromJson(e)).toList();
    }
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
    final response = await _client.rpc(
      'get_lounge_categories',
      params: {'p_lounge_id': loungeId},
    );
    return (response as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  @override
  Future<List<ReviewModel>> getLoungeReviews(String loungeId) async {
    try {
      final response = await _client
          .from('lounge_reviews')
          .select('*, profiles:user_id(name, avatar_url, full_name)')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      try {
        final response = await _client
            .from('reviews')
            .select('*, profiles:user_id(name, avatar_url, full_name)')
            .eq('lounge_id', loungeId)
            .order('created_at', ascending: false);
        return (response as List).map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {
        return [];
      }
    }
  }
}

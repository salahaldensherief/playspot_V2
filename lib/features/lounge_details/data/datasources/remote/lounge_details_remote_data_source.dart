import 'dart:developer' as dev;
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
    if (loungeId.isEmpty) return [];

    Future<List<ReviewModel>> processAndHydrate(List<dynamic> rawList) async {
      final list = rawList.map((e) {
        try {
          return ReviewModel.fromJson(Map<String, dynamic>.from(e));
        } catch (err) {
          dev.log("[REVIEWS_DS] Review parse error: $err for item $e");
          return null;
        }
      }).whereType<ReviewModel>().where((r) => r.rating > 0 || (r.comment != null && r.comment!.isNotEmpty)).toList();

      if (list.isEmpty) return list;

      final missingProfileUserIds = list
          .where((r) => (r.userName == 'User' || r.userName.trim().isEmpty) && r.userId.isNotEmpty)
          .map((r) => r.userId)
          .toSet()
          .toList();

      if (missingProfileUserIds.isNotEmpty) {
        try {
          final profilesRes = await _client
              .from('profiles')
              .select('id, name, full_name, avatar_url')
              .inFilter('id', missingProfileUserIds);

          final profilesMap = <String, Map<String, dynamic>>{};
          for (final p in (profilesRes as List)) {
            final id = p['id']?.toString();
            if (id != null) profilesMap[id] = Map<String, dynamic>.from(p);
          }

          return list.map((r) {
            if ((r.userName == 'User' || r.userName.trim().isEmpty) && profilesMap.containsKey(r.userId)) {
              final p = profilesMap[r.userId]!;
              final name = p['full_name']?.toString() ?? p['name']?.toString() ?? 'User';
              final avatar = p['avatar_url']?.toString();
              return ReviewModel(
                id: r.id,
                userId: r.userId,
                userName: name.isNotEmpty ? name : 'User',
                userAvatar: avatar ?? r.userAvatar,
                rating: r.rating,
                comment: r.comment,
                createdAt: r.createdAt,
              );
            }
            return r;
          }).toList();
        } catch (e) {
          dev.log("[REVIEWS_DS] Profiles hydration error: $e");
        }
      }

      return list;
    }

    // Attempt 1: lounge_reviews table with profiles join
    try {
      final res = await _client
          .from('lounge_reviews')
          .select('*, profiles:user_id(name, avatar_url, full_name)')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      final result = await processAndHydrate(res as List);
      if (result.isNotEmpty) return result;
    } catch (e) {
      dev.log("[REVIEWS_DS] lounge_reviews with profiles join error: $e");
    }

    // Attempt 2: lounge_reviews table flat select
    try {
      final res = await _client
          .from('lounge_reviews')
          .select('*')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      final result = await processAndHydrate(res as List);
      if (result.isNotEmpty) return result;
    } catch (e) {
      dev.log("[REVIEWS_DS] lounge_reviews flat select error: $e");
    }

    // Attempt 3: reviews table with profiles join
    try {
      final res = await _client
          .from('reviews')
          .select('*, profiles:user_id(name, avatar_url, full_name)')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      final result = await processAndHydrate(res as List);
      if (result.isNotEmpty) return result;
    } catch (e) {
      dev.log("[REVIEWS_DS] reviews with profiles join error: $e");
    }

    // Attempt 4: reviews table flat select
    try {
      final res = await _client
          .from('reviews')
          .select('*')
          .eq('lounge_id', loungeId)
          .order('created_at', ascending: false);
      final result = await processAndHydrate(res as List);
      if (result.isNotEmpty) return result;
    } catch (e) {
      dev.log("[REVIEWS_DS] reviews flat select error: $e");
    }

    // Attempt 5: bookings table with ratings
    try {
      final res = await _client
          .from('bookings')
          .select('id, user_id, rating, comment, review, created_at')
          .eq('lounge_id', loungeId)
          .not('rating', 'is', null)
          .gt('rating', 0)
          .order('created_at', ascending: false);
      final result = await processAndHydrate(res as List);
      if (result.isNotEmpty) return result;
    } catch (e) {
      dev.log("[REVIEWS_DS] bookings table ratings fallback error: $e");
    }

    return [];
  }
}

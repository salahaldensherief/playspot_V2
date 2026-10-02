import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../models/promo_model.dart';
import '../../models/category_model.dart';
import '../../models/home_params.dart';

import 'home_remote_data_source.dart';

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;
  HomeRemoteDataSourceImpl(this._client);

  Future<List<LoungeModel>> _hydrateLoungesWithPromotions(
    List<dynamic> rawLounges,
  ) async {
    final loungeMaps = rawLounges
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    bool needsPromoFetch = loungeMaps.any(
      (l) =>
          (l['promotions'] == null ||
              (l['promotions'] is List && (l['promotions'] as List).isEmpty)) &&
          l['has_discount'] != true,
    );

    if (needsPromoFetch) {
      try {
        final promosRes = await _client
            .from('promotions')
            .select()
            .eq('is_active', true);
        if (promosRes.isNotEmpty) {
          final Map<String, List<Map<String, dynamic>>> promoByLounge = {};
          for (var p in promosRes) {
            final lid = p['lounge_id']?.toString();
            if (lid != null && lid.isNotEmpty) {
              promoByLounge
                  .putIfAbsent(lid, () => [])
                  .add(Map<String, dynamic>.from(p));
            }
          }
          for (var l in loungeMaps) {
            final lid = l['id']?.toString();
            if (lid != null &&
                (l['promotions'] == null ||
                    (l['promotions'] is List &&
                        (l['promotions'] as List).isEmpty))) {
              if (promoByLounge.containsKey(lid)) {
                l['promotions'] = promoByLounge[lid];
              }
            }
          }
        }
      } catch (e) {
        AppLogger.warning("LOUNGE_PROMO_HYDRATION_ERROR: $e");
      }
    }

    return loungeMaps.map((e) => LoungeModel.fromJson(e)).toList();
  }

  @override
  Future<LoungeModel?> getLoungeById(String id) async {
    try {
      final response = await _client
          .from('lounges')
          .select(
            '*, promotions:promotions!lounge_id(id, tag_ar, tag_en, is_active, expires_at, discount_value, discount_type, discount_percentage, title_ar, title_en)',
          )
          .eq('id', id)
          .eq('status', 'active')
          .eq('is_active', true)
          .maybeSingle();
      if (response != null) {
        final hydrated = await _hydrateLoungesWithPromotions([response]);
        if (hydrated.isNotEmpty) return hydrated.first;
      }
      return null;
    } catch (e) {
      try {
        final fallbackRes = await _client
            .from('lounges')
            .select()
            .eq('id', id)
            .eq('status', 'active')
            .eq('is_active', true)
            .maybeSingle();
        if (fallbackRes == null) return null;
        final hydrated = await _hydrateLoungesWithPromotions([fallbackRes]);
        if (hydrated.isNotEmpty) return hydrated.first;
        return null;
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<int> getUserPoints(String userId) async {
    try {
      final response = await _client.rpc(
        'get_user_points_balance',
        params: {'p_user_id': userId},
      );
      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<LoungeModel>> getLounges(GetLoungesParams params) async {
    final response = await _client.rpc(
      'discover_lounges',
      params: params.toJson(),
    );

    final list = response is List
        ? response
        : (response is Map && response['data'] is List
              ? response['data'] as List
              : const <dynamic>[]);

    return list
        .map(
          (item) =>
              LoungeModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableCities() async {
    final res = await _client.rpc('get_available_cities');
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<PromoModel>> getPromotions({String? loungeId}) async {
    try {
      AppLogger.info("FETCHING_PROMOTIONS: loungeId=$loungeId");

      final response = await _client.rpc(
        'get_active_promos',
        params: {'p_lounge_id': loungeId},
      );

      final List data = response as List;
      AppLogger.info("PROMOTIONS_RAW_DATA_COUNT: ${data.length}");

      final promos = data
          .map((e) {
            try {
              return PromoModel.fromJson(Map<String, dynamic>.from(e));
            } catch (e) {
              AppLogger.warning("PROMO_PARSING_ERROR: $e");
              return null;
            }
          })
          .whereType<PromoModel>()
          .toList();

      AppLogger.info("PROMOTIONS_PARSED_SUCCESSFULLY: ${promos.length}");
      return promos;
    } catch (e) {
      AppLogger.error("GET_PROMOTIONS_CRITICAL_ERROR: $e");
      try {
        var query = _client
            .from('promotions')
            .select()
            .eq('is_active', true)
            .gt('expires_at', DateTime.now().toIso8601String());
        if (loungeId != null && loungeId.isNotEmpty) {
          query = query.eq('lounge_id', loungeId);
        }
        final fallbackRes = await query;
        final List data = fallbackRes as List;
        return data
            .map((e) {
              try {
                return PromoModel.fromJson(Map<String, dynamic>.from(e));
              } catch (_) {
                return null;
              }
            })
            .whereType<PromoModel>()
            .toList();
      } catch (fallbackError) {
        AppLogger.error("GET_PROMOTIONS_FALLBACK_ERROR: $fallbackError");
        return [];
      }
    }
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final res = await _client.from('categories').select().order('id');
    return (res as List).map((e) => CategoryModel.fromJson(e)).toList();
  }
}

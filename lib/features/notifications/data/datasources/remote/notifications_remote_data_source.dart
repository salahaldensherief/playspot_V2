import 'dart:async';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/core/models/paginated_response.dart';
import '../../models/notification_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<PaginatedResponse<NotificationModel>> getNotifications(
    String lang, {
    int page = 1,
    int pageSize = 20,
  });
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Stream<Map<String, dynamic>> subscribeToNewNotifications();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  NotificationsRemoteDataSourceImpl(this._client);

  @override
  Future<PaginatedResponse<NotificationModel>> getNotifications(
    String lang, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      dev.log("FETCHING_NOTIFICATIONS_PAGE: lang=$lang, page=$page, pageSize=$pageSize");
      final response = await _client.rpc('get_notifications_page', params: {
        'p_page': page,
        'p_page_size': pageSize,
      });

      return PaginatedResponse.fromRpc(
        response: response,
        fromJson: (json) => NotificationModel.fromJson(json),
        requestedPage: page,
        requestedPageSize: pageSize,
      );
    } catch (e) {
      dev.log("FETCH_NOTIFICATIONS_ERROR: $e");
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.rpc('mark_notification_read', params: {'p_notification_id': notificationId});
    } catch (e) {
      dev.log("RPC mark_notification_read failed, trying direct table update: $e");
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId)
            .eq('user_id', userId);
      }
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _client.rpc('mark_all_notifications_read');
    } catch (e) {
      dev.log("RPC mark_all_notifications_read failed, trying direct table update: $e");
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId);
      }
    }
  }

  @override
  Stream<Map<String, dynamic>> subscribeToNewNotifications() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    final controller = StreamController<Map<String, dynamic>>();

    _channel = _client.channel('public:notifications:user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      if (_channel != null) {
        _client.removeChannel(_channel!);
        _channel = null;
      }
    };

    return controller.stream;
  }
}

import 'dart:async';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<NotificationModel>> getNotifications(String lang);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Stream<Map<String, dynamic>> subscribeToNewNotifications();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  NotificationsRemoteDataSourceImpl(this._client);

  @override
  Future<List<NotificationModel>> getNotifications(String lang) async {
    try {
      dev.log("FETCHING_NOTIFICATIONS: lang=$lang");
      final response = await _client.rpc('get_notifications', params: {'p_lang': lang});
      final List list = response as List;
      
      return list.map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      dev.log("FETCH_NOTIFICATIONS_ERROR: $e");
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _client.rpc('mark_notification_read', params: {'p_notification_id': notificationId});
  }

  @override
  Future<void> markAllAsRead() async {
    await _client.rpc('mark_all_notifications_read');
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

    return controller.stream;
  }
}

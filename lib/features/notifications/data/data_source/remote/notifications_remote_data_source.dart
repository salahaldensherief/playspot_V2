import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<NotificationModel>> getNotifications(String lang);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final SupabaseClient _client;
  NotificationsRemoteDataSourceImpl(this._client);

  @override
  Future<List<NotificationModel>> getNotifications(String lang) async {
    try {
      dev.log("FETCHING_NOTIFICATIONS: lang=$lang");
      final response = await _client.rpc('get_notifications', params: {'p_lang': lang});
      final List list = response as List;
      dev.log("NOTIFICATIONS_COUNT: ${list.length}");
      
      final notifications = list.map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e))).toList();
      
      for (var n in notifications) {
        dev.log("NOTIFICATION: id=${n.id}, title=${n.title}, isRead=${n.isRead}");
      }
      
      return notifications;
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
}

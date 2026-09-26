import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cache/preference_manager.dart';
import '../../di.dart';

/// Abstract Strategy interface for notification navigation & actions.
/// Encapsulates routing logic for specific FCM notification payload types.
abstract class NotificationActionStrategy {
  /// Checks if this strategy can handle the provided notification data payload.
  bool canHandle(Map<String, dynamic> data);

  /// Executes navigation or action corresponding to the notification payload.
  /// Returns true if handled successfully, false otherwise.
  bool handle(Map<String, dynamic> data);
}

/// Helper methods for Notification Action Strategies.
class NotificationStrategyHelper {
  NotificationStrategyHelper._();

  /// Sanitizes raw string inputs by trimming and filtering 'null', 'undefined', or empty strings.
  static String? cleanString(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') {
      return null;
    }
    return str;
  }

  /// Verifies if user is authenticated via local preference and Supabase session.
  static bool isAuthenticated() {
    if (!sl.isRegistered<PreferenceManager>()) return false;
    final pref = sl<PreferenceManager>();
    final supabase = sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null;
    final hasSession = supabase?.auth.currentSession != null;
    return pref.isLoggedIn && hasSession;
  }

  /// Safely extracts booking ID without confusing it with notification row ID.
  static String? getBookingId(Map<String, dynamic> data) {
    final directBookingId = cleanString(data['booking_id']) ?? cleanString(data['bookingId']);
    if (directBookingId != null) return directBookingId;

    if (data['data'] is Map) {
      final nested = Map<String, dynamic>.from(data['data'] as Map);
      final nestedBookingId = cleanString(nested['booking_id']) ?? cleanString(nested['bookingId']);
      if (nestedBookingId != null) return nestedBookingId;
    }
    return null;
  }

  /// Safely extracts session ID without confusing it with plain booking notifications.
  static String? getSessionId(Map<String, dynamic> data) {
    final directSessionId = cleanString(data['session_id']) ?? cleanString(data['sessionId']);
    if (directSessionId != null) return directSessionId;

    if (data['data'] is Map) {
      final nested = Map<String, dynamic>.from(data['data'] as Map);
      final nestedSessionId = cleanString(nested['session_id']) ?? cleanString(nested['sessionId']);
      if (nestedSessionId != null) return nestedSessionId;
    }

    // Only fallback to booking_id if payload type is explicitly a session notification
    final type = cleanString(data['type'])?.toLowerCase();
    if (type == 'session' || type == 'active_session' || type == 'active-session') {
      return getBookingId(data);
    }

    return null;
  }

  /// Safely extracts tournament ID.
  static String? getTournamentId(Map<String, dynamic> data) {
    final directTournamentId = cleanString(data['tournament_id']) ?? cleanString(data['tournamentId']);
    if (directTournamentId != null) return directTournamentId;

    if (data['data'] is Map) {
      final nested = Map<String, dynamic>.from(data['data'] as Map);
      final nestedTournamentId = cleanString(nested['tournament_id']) ?? cleanString(nested['tournamentId']);
      if (nestedTournamentId != null) return nestedTournamentId;
    }
    return null;
  }
}


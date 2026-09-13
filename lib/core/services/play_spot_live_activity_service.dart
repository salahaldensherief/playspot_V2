import 'dart:developer' as dev;
import 'package:live_activities/live_activities.dart';

class PlaySpotLiveActivityService {
  static final PlaySpotLiveActivityService instance = PlaySpotLiveActivityService._internal();
  PlaySpotLiveActivityService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  bool _isSupported = false;
  String? _currentActivityId;

  Future<void> init() async {
    try {
      // Initialize with app group if required by package
      // await _liveActivitiesPlugin.init(appGroupId: 'group.com.playspot.app');
      _isSupported = true;
      dev.log("[LiveActivity] Initialized");
    } catch (e) {
      dev.log("[LiveActivity] Init error: $e");
    }
  }

  Future<void> startActivity({
    required String sessionId,
    required String hallName,
    required String deviceName,
    required int endTimeTimestamp,
  }) async {
    try {
      _currentActivityId = sessionId;
      final activityId = await _liveActivitiesPlugin.createActivity(
        sessionId,
        {
          'hallName': hallName,
          'deviceName': deviceName,
          'endTime': endTimeTimestamp,
        },
      );
      dev.log("[LiveActivity] Created activity with id: $activityId");
    } catch (e) {
      dev.log("[LiveActivity] Error starting activity: $e");
    }
  }

  Future<void> updateActivity({
    required String hallName,
    required String deviceName,
    required int endTimeTimestamp,
  }) async {
    if (_currentActivityId == null) return;
    try {
      await _liveActivitiesPlugin.updateActivity(
        _currentActivityId!,
        {
          'hallName': hallName,
          'deviceName': deviceName,
          'endTime': endTimeTimestamp,
        },
      );
      dev.log("[LiveActivity] Updated activity");
    } catch (e) {
      dev.log("[LiveActivity] Error updating activity: $e");
    }
  }

  Future<void> endActivity() async {
    if (_currentActivityId == null) return;
    try {
      await _liveActivitiesPlugin.endActivity(_currentActivityId!);
      _currentActivityId = null;
      dev.log("[LiveActivity] Ended activity");
    } catch (e) {
      dev.log("[LiveActivity] Error ending activity: $e");
    }
  }
}

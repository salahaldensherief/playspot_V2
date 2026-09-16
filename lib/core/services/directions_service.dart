import 'package:flutter/foundation.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cache/preference_manager.dart';

abstract class DirectionsService {
  Future<bool> openDirections({
    required double? lat,
    required double? lng,
    required String? loungeName,
    String? loungeLocation,
    String? mapsLink,
  });
}

class DirectionsServiceImpl implements DirectionsService {
  final PreferenceManager preferenceManager;

  DirectionsServiceImpl(this.preferenceManager);

  @override
  Future<bool> openDirections({
    required double? lat,
    required double? lng,
    required String? loungeName,
    String? loungeLocation,
    String? mapsLink,
  }) async {
    // 1. Try lat & lng coordinates
    if (lat != null && lng != null) {
      try {
        final userLat = double.tryParse(preferenceManager.latitude());
        final userLng = double.tryParse(preferenceManager.longitude());

        await MapLauncher.directions(
          Location.coords(lat, lng, title: loungeName ?? ''),
          from: (userLat != null && userLng != null)
              ? Location.coords(userLat, userLng, title: "My Location")
              : null,
        ).show();
        return true;
      } catch (e) {
        debugPrint('[DirectionsService] MapLauncher error: $e');
      }

      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      );
      try {
        if (await canLaunchUrl(googleMapsUrl)) {
          await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
          return true;
        } else {
          await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
          return true;
        }
      } catch (e) {
        debugPrint('[DirectionsService] URL Launcher error: $e');
      }
    }

    // 2. Fallback to mapsLink if lat/lng unavailable
    if (mapsLink != null && mapsLink.isNotEmpty) {
      final uri = Uri.tryParse(mapsLink);
      if (uri != null) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return true;
          }
        } catch (e) {
          debugPrint('[DirectionsService] mapsLink launch error: $e');
        }
      }
    }

    // 3. Fallback to search query
    final query = '${loungeName ?? ''} ${loungeLocation ?? ''}'.trim();
    if (query.isNotEmpty) {
      final searchUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
      );
      try {
        if (await canLaunchUrl(searchUrl)) {
          await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
          return true;
        } else {
          await launchUrl(searchUrl, mode: LaunchMode.platformDefault);
          return true;
        }
      } catch (e) {
        debugPrint('[DirectionsService] Search URL Launcher error: $e');
      }
    }

    return false;
  }
}

import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

abstract class LocationService {
  Future<Position?> getCurrentLocation();
  Future<String?> getAddressFromLatLng(double lat, double lng);
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
}

class LocationServiceImpl implements LocationService {
  @override
  Future<Position?> getCurrentLocation() async {
    try {
       LocationPermission permission = await checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          log("LOCATION_SERVICE: Permission denied by user");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        log("LOCATION_SERVICE: Permission denied forever");
        return null;
      }

      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        log("LOCATION_SERVICE: GPS is disabled, prompting user...");
        // This might prompt the user to enable GPS on some devices
        await Geolocator.openLocationSettings();
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      log("LOCATION_SERVICE_ERROR: $e");
      return null;
    }
  }

  @override
  Future<String?> getAddressFromLatLng(double lat, double lng) async {
    try {
      // Timeout to prevent long waiting on bad networks
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 3));
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Smart formatting: Priority to neighborhood then city
        final area = place.subLocality ?? place.locality ?? place.administrativeArea;
        final city = place.locality ?? place.administrativeArea;
        if (area != null && city != null && area != city) {
          return "$area, $city";
        }
        return area ?? city ?? "Unknown Location";
      }
      return null;
    } catch (e) {
      // Don't log full error for network-related geocoding issues
      log("GEOCODING_INFO: Could not resolve address (Check network/Simulator)");
      return null;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
}

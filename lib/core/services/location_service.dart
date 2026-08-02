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
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        log("LOCATION_SERVICE: Service is disabled");
        return null;
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          log("LOCATION_SERVICE: Permission denied");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        log("LOCATION_SERVICE: Permission denied forever");
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
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.subLocality}, ${place.locality}";
      }
      return null;
    } catch (e) {
      log("LOCATION_SERVICE_ERROR (Geocoding): $e");
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

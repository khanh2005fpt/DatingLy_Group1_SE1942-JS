import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// LocationRepository: Quản lý định vị GPS và quyền truy cập vị trí (PRM393 MVVM Pattern)
class LocationRepository {
  Future<GeoPoint?> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 8));
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('LocationRepository error: $e');
      return null;
    }
  }
}


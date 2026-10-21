import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Lấy vị trí hiện tại. Trả về null nếu bị từ chối quyền / tắt GPS / lỗi,
/// để Discovery vẫn chạy bình thường (chỉ ẩn khoảng cách).
class LocationService {
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
      debugPrint('LocationService error: $e');
      return null;
    }
  }
}

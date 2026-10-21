import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_prm/core/utils/geo_utils.dart';
import 'package:project_prm/data/models/discovery_filter.dart';
import 'package:project_prm/data/services/preferences_service.dart';

void main() {
  test('haversine Hà Nội - TP.HCM ≈ 1150 km', () {
    final km = haversineKm(21.0278, 105.8342, 10.8231, 106.6297);
    expect(km, inInclusiveRange(1130, 1170));
  });

  test('filter: mặc định khi chưa lưu', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PreferencesService.init();
    final f = p.loadDiscoveryFilter();
    expect(f.minAge, 18);
    expect(f.maxAge, 35);
    expect(f.maxDistanceKm, 50);
    expect(f.interestedIn, DiscoveryFilter.anyGender);
  });

  test('filter: lưu rồi đọc lại đúng 4 key', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PreferencesService.init();
    await p.saveDiscoveryFilter(const DiscoveryFilter(
      minAge: 22,
      maxAge: 40,
      maxDistanceKm: 10,
      interestedIn: 'Nữ',
      interests: ['Game'],
      requireCommonInterest: true,
    ));
    final raw = await SharedPreferences.getInstance();
    expect(raw.getInt('min_age'), 22);
    expect(raw.getInt('max_age'), 40);
    expect(raw.getInt('max_distance'), 10);
    expect(raw.getString('interested_in'), 'Nữ');
    final f = p.loadDiscoveryFilter();
    expect(f.interests, ['Game']);
    expect(f.requireCommonInterest, isTrue);
  });
}

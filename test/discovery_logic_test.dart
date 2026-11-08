import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_prm/data/repositories/geo_utils.dart';
import 'package:project_prm/data/models/discovery_filter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_prm/data/models/user_model.dart';
import 'package:project_prm/data/repositories/discovery_repository.dart';
import 'package:project_prm/data/repositories/setting_repository.dart';

void main() {
  group('passesDiscoveryFilter', () {
    const filter = DiscoveryFilter(minAge: 20, maxAge: 30, maxDistanceKm: 10);
    const hanoi = GeoPoint(21.0278, 105.8342);
    final base = <String, dynamic>{
      'full_name': 'Lan',
      'age': 25,
      'gender': 'Nữ',
      'tags': ['Game'],
      'location': const GeoPoint(21.03, 105.84), // ~1 km
    };
    bool pass(Map<String, dynamic> data,
        {DiscoveryFilter f = filter, GeoPoint? me = hanoi}) {
      final m = {...base, ...data}..removeWhere((_, v) => v == null);
      return passesDiscoveryFilter(
        myId: 'me',
        data: m,
        user: UserModel.fromMap(m, 'u1'),
        filter: f,
        myLocation: me,
      );
    }

    test('hợp lệ thì qua', () => expect(pass({}), isTrue));
    test('ngoài độ tuổi', () => expect(pass({'age': 31}), isFalse));
    test('sai giới tính',
        () => expect(pass({}, f: filter.copyWith(interestedIn: 'Nam')), isFalse));
    test('đối phương chặn mình',
        () => expect(pass({'blocked_users': ['me']}), isFalse));
    test('ghost mode', () => expect(pass({'ghost_mode': true}), isFalse));
    test('hồ sơ chưa có tên', () => expect(pass({'full_name': ' '}), isFalse));
    test('xa hơn max_distance', () {
      expect(pass({'location': const GeoPoint(10.82, 106.63)}), isFalse);
    });
    test('không có vị trí bị ẩn khi mình có vị trí', () {
      expect(pass({'location': null}), isFalse);
      expect(pass({'location': null}, me: null), isTrue);
    });
    test('chip sở thích lọc dù tắt công tắc', () {
      expect(pass({}, f: filter.copyWith(interests: ['Yoga'])), isFalse);
      expect(pass({}, f: filter.copyWith(interests: ['Game'])), isTrue);
    });
  });

  test('haversine Hà Nội - TP.HCM ≈ 1150 km', () {
    final km = haversineKm(21.0278, 105.8342, 10.8231, 106.6297);
    expect(km, inInclusiveRange(1130, 1170));
  });

  test('filter: mặc định khi chưa lưu', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SettingRepository.init();
    final f = p.loadDiscoveryFilter();
    expect(f.minAge, 18);
    expect(f.maxAge, 35);
    expect(f.maxDistanceKm, 50);
    expect(f.interestedIn, DiscoveryFilter.anyGender);
  });

  test('filter: lưu rồi đọc lại đúng 4 key', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SettingRepository.init();
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

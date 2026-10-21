import 'package:shared_preferences/shared_preferences.dart';
import '../models/discovery_filter.dart';

/// Dịch vụ quản lý lưu trữ cấu hình cục bộ bằng SharedPreferences (PRM393 Requirement)
class PreferencesService {
  static const String _keyDarkMode = 'cfg_dark_mode';
  static const String _keyHasSeenOnboarding = 'cfg_has_seen_onboarding';
  static const String _keyGenderFilter = 'cfg_gender_filter';
  static const String _keyNotificationsEnabled = 'cfg_notifications_enabled';
  static const String _keyFcmToken = 'cfg_fcm_token';
  static const String _keyMinAge = 'min_age';
  static const String _keyMaxAge = 'max_age';
  static const String _keyMaxDistance = 'max_distance';
  static const String _keyInterestedIn = 'interested_in';
  static const String _keyFilterInterests = 'filter_interests';
  static const String _keyRequireCommon = 'require_common_interest';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  // Khởi tạo SharedPreferences instance
  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // --- Dark Mode ---
  bool get isDarkMode => _prefs.getBool(_keyDarkMode) ?? false;
  Future<bool> setDarkMode(bool value) => _prefs.setBool(_keyDarkMode, value);

  // --- Onboarding ---
  bool get hasSeenOnboarding => _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  Future<bool> setHasSeenOnboarding(bool value) =>
      _prefs.setBool(_keyHasSeenOnboarding, value);

  // --- Bộ lọc giới tính Discovery ---
  String? get genderFilter => _prefs.getString(_keyGenderFilter);
  Future<bool> setGenderFilter(String? value) {
    if (value == null) {
      return _prefs.remove(_keyGenderFilter);
    }
    return _prefs.setString(_keyGenderFilter, value);
  }

  // --- Bật/Tắt Thông báo Notification ---
  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? true;
  Future<bool> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_keyNotificationsEnabled, value);

  // --- Bộ lọc Discovery (min_age, max_age, max_distance, interested_in) ---
  DiscoveryFilter loadDiscoveryFilter() {
    // Tương thích ngược: dùng giá trị tab giới tính cũ làm mặc định
    final legacy = _prefs.getString(_keyGenderFilter);
    return DiscoveryFilter(
      minAge: _prefs.getInt(_keyMinAge) ?? 18,
      maxAge: _prefs.getInt(_keyMaxAge) ?? 35,
      maxDistanceKm: _prefs.getInt(_keyMaxDistance) ?? 50,
      interestedIn:
          _prefs.getString(_keyInterestedIn) ?? legacy ?? DiscoveryFilter.anyGender,
      interests: _prefs.getStringList(_keyFilterInterests) ?? const [],
      requireCommonInterest: _prefs.getBool(_keyRequireCommon) ?? false,
    );
  }

  Future<void> saveDiscoveryFilter(DiscoveryFilter f) async {
    await _prefs.setInt(_keyMinAge, f.minAge);
    await _prefs.setInt(_keyMaxAge, f.maxAge);
    await _prefs.setInt(_keyMaxDistance, f.maxDistanceKm);
    await _prefs.setString(_keyInterestedIn, f.interestedIn);
    await _prefs.setStringList(_keyFilterInterests, f.interests);
    await _prefs.setBool(_keyRequireCommon, f.requireCommonInterest);
  }

  // --- FCM Token Cache ---
  String? get fcmToken => _prefs.getString(_keyFcmToken);
  Future<bool> setFcmToken(String? token) {
    if (token == null) return _prefs.remove(_keyFcmToken);
    return _prefs.setString(_keyFcmToken, token);
  }

}

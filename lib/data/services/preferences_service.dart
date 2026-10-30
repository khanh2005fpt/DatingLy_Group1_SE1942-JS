import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ quản lý lưu trữ cấu hình cục bộ bằng SharedPreferences (PRM393 Requirement)
class PreferencesService {
  static const String _keyDarkMode = 'cfg_dark_mode';
  static const String _keyHasSeenOnboarding = 'cfg_has_seen_onboarding';
  static const String _keyGenderFilter = 'cfg_gender_filter';
  static const String _keyNotificationsEnabled = 'cfg_notifications_enabled';
  static const String _keyFcmToken = 'cfg_fcm_token';
  static const String _keyGhostMode = 'cfg_ghost_mode';

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

  // --- FCM Token Cache ---
  String? get fcmToken => _prefs.getString(_keyFcmToken);
  Future<bool> setFcmToken(String? token) {
    if (token == null) return _prefs.remove(_keyFcmToken);
    return _prefs.setString(_keyFcmToken, token);
  }

  // --- Ghost Mode (Ẩn danh / Pause account) ---
  bool get ghostMode => _prefs.getBool(_keyGhostMode) ?? false;
  Future<bool> setGhostMode(bool value) => _prefs.setBool(_keyGhostMode, value);

  // --- Clear All (dùng khi Logout) ---
  Future<void> clearAll() async => _prefs.clear();

}

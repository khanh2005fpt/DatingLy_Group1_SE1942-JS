import 'package:shared_preferences/shared_preferences.dart';
import '../models/discovery_filter.dart';
import '../models/user_model.dart';

/// SettingRepository: Quản lý cấu hình cục bộ và SharedPreferences (PRM393 MVVM Pattern)
class SettingRepository {
  static const String _keyDarkMode = 'cfg_dark_mode';
  static const String _keyDarkModeTheme = 'dark_mode_theme';
  static const String _keyHasSeenOnboarding = 'cfg_has_seen_onboarding';
  static const String _keyIsFirstTimeUser = 'cfg_is_first_time_user';
  static const String _keyOnboardingCompleted = 'cfg_onboarding_completed';
  static const String _keyCachedUserProfile = 'cfg_cached_user_profile';
  static const String _keyGenderFilter = 'cfg_gender_filter';
  static const String _keyNotificationsEnabled = 'cfg_notifications_enabled';
  static const String _keyNotificationEnabled = 'notification_enabled';
  static const String _keyGhostMode = 'ghost_mode';
  static const String _keyFcmToken = 'cfg_fcm_token';
  static const String _keyMinAge = 'min_age';
  static const String _keyMaxAge = 'max_age';
  static const String _keyMaxDistance = 'max_distance';
  static const String _keyInterestedIn = 'interested_in';
  static const String _keyFilterInterests = 'filter_interests';
  static const String _keyRequireCommon = 'require_common_interest';

  final SharedPreferences _prefs;
  static SettingRepository? _instance;

  SettingRepository(this._prefs) {
    _instance = this;
  }

  static SettingRepository? get instance => _instance;

  // Khởi tạo SharedPreferences instance
  static Future<SettingRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingRepository(prefs);
    _instance = repo;
    return repo;
  }

  // --- First Time User Flag ---
  bool get isFirstTimeUser => _prefs.getBool(_keyIsFirstTimeUser) ?? true;
  Future<bool> setIsFirstTimeUser(bool value) =>
      _prefs.setBool(_keyIsFirstTimeUser, value);

  // --- Onboarding Completed Flag ---
  bool get onboardingCompleted =>
      _prefs.getBool(_keyOnboardingCompleted) ??
      _prefs.getBool(_keyHasSeenOnboarding) ??
      false;

  Future<bool> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_keyHasSeenOnboarding, value);
    return _prefs.setBool(_keyOnboardingCompleted, value);
  }

  // --- Cached User Profile (JSON) ---
  Future<bool> cacheUserProfile(UserModel user) {
    return _prefs.setString(_keyCachedUserProfile, user.toJsonString());
  }

  UserModel? getCachedUserProfile() {
    final raw = _prefs.getString(_keyCachedUserProfile);
    if (raw == null || raw.isEmpty) return null;
    return UserModel.fromJsonString(raw);
  }

  Future<bool> clearCachedUserProfile() {
    return _prefs.remove(_keyCachedUserProfile);
  }

  // --- Dark Mode ---
  bool get isDarkMode =>
      _prefs.getBool(_keyDarkModeTheme) ??
      _prefs.getBool(_keyDarkMode) ??
      false;
  Future<bool> setDarkMode(bool value) async {
    await _prefs.setBool(_keyDarkMode, value);
    return _prefs.setBool(_keyDarkModeTheme, value);
  }

  // --- Ghost Mode ---
  bool get ghostMode => _prefs.getBool(_keyGhostMode) ?? false;
  Future<bool> setGhostMode(bool value) => _prefs.setBool(_keyGhostMode, value);

  // --- Legacy Alias ---
  bool get hasSeenOnboarding => onboardingCompleted;
  Future<bool> setHasSeenOnboarding(bool value) => setOnboardingCompleted(value);

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
      _prefs.getBool(_keyNotificationEnabled) ??
      _prefs.getBool(_keyNotificationsEnabled) ??
      true;
  Future<bool> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_keyNotificationsEnabled, value);
    return _prefs.setBool(_keyNotificationEnabled, value);
  }

  // --- Xoá toàn bộ cache cục bộ SharedPreferences ---
  Future<bool> clearAll() => _prefs.clear();

  // --- Bộ lọc Discovery ---
  DiscoveryFilter loadDiscoveryFilter() {
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


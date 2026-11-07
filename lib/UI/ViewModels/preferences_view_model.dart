import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/repositories/setting_repository.dart';

part 'preferences_view_model.g.dart';

class PreferencesState {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final String? genderFilter;

  const PreferencesState({
    required this.isDarkMode,
    required this.notificationsEnabled,
    this.genderFilter,
  });

  PreferencesState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? genderFilter,
  }) {
    return PreferencesState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      genderFilter: genderFilter ?? this.genderFilter,
    );
  }
}

@Riverpod(keepAlive: true)
class PreferencesViewModel extends _$PreferencesViewModel {
  SettingRepository get _settingRepo => ref.read(settingRepositoryProvider);

  @override
  PreferencesState build() => PreferencesState(
        isDarkMode: _settingRepo.isDarkMode,
        notificationsEnabled: _settingRepo.notificationsEnabled,
        genderFilter: _settingRepo.genderFilter,
      );

  Future<void> toggleDarkMode() async {
    final newMode = !state.isDarkMode;
    await _settingRepo.setDarkMode(newMode);
    state = state.copyWith(isDarkMode: newMode);
  }

  Future<void> toggleNotifications() async {
    final newStatus = !state.notificationsEnabled;
    await _settingRepo.setNotificationsEnabled(newStatus);
    state = state.copyWith(notificationsEnabled: newStatus);
  }

  Future<void> setGenderFilter(String? gender) async {
    await _settingRepo.setGenderFilter(gender);
    state = state.copyWith(genderFilter: gender);
  }
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/services/preferences_service.dart';

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

class PreferencesViewModel extends Notifier<PreferencesState> {
  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  PreferencesState build() => PreferencesState(
        isDarkMode: _prefs.isDarkMode,
        notificationsEnabled: _prefs.notificationsEnabled,
        genderFilter: _prefs.genderFilter,
      );

  Future<void> toggleDarkMode() async {
    final newMode = !state.isDarkMode;
    await _prefs.setDarkMode(newMode);
    state = state.copyWith(isDarkMode: newMode);
  }

  Future<void> toggleNotifications() async {
    final newStatus = !state.notificationsEnabled;
    await _prefs.setNotificationsEnabled(newStatus);
    state = state.copyWith(notificationsEnabled: newStatus);
  }

  Future<void> setGenderFilter(String? gender) async {
    await _prefs.setGenderFilter(gender);
    state = state.copyWith(genderFilter: gender);
  }
}

final preferencesViewModelProvider =
    NotifierProvider<PreferencesViewModel, PreferencesState>(
        PreferencesViewModel.new);

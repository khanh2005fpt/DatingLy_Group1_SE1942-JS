import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_helper.dart';
import 'setting_repository.dart';
import 'auth_repository.dart';
import 'user_repository.dart';
import 'discovery_repository.dart';
import 'chat_repository.dart';
import 'notification_repository.dart';
import 'location_repository.dart';
import 'ai_repository.dart';
import 'seed_repository.dart';

// --- Data Helper ---
final dataHelperProvider = Provider<DataHelper>((ref) => DataHelper());

// --- Repositories (PRM393 MVVM Architecture) ---
final settingRepositoryProvider = Provider<SettingRepository>((ref) {
  throw UnimplementedError('settingRepositoryProvider must be overridden in main.dart');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  throw UnimplementedError('notificationRepositoryProvider must be overridden in main.dart');
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

final seedRepositoryProvider = Provider<SeedRepository>((ref) {
  return SeedRepository();
});

final authStateChangesProvider = StreamProvider((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});


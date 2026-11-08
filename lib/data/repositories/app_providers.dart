import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'data_helper.dart';
import 'setting_repository.dart';
import 'auth_repository.dart';
import 'user_repository.dart';
import 'discovery_repository.dart';
import 'chat_repository.dart';
import 'notification_repository.dart';
import 'location_repository.dart';
import 'ai_repository.dart';
import 'activity_repository.dart';
import '../local/database_helper.dart';

part 'app_providers.g.dart';

// --- Data Helper ---
@Riverpod(keepAlive: true)
DataHelper dataHelper(Ref ref) => DataHelper();

// --- Repositories (PRM393 MVVM Architecture) ---
@Riverpod(keepAlive: true)
SettingRepository settingRepository(Ref ref) {
  throw UnimplementedError('settingRepositoryProvider must be overridden in main.dart');
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository();

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) => UserRepository();

@Riverpod(keepAlive: true)
DiscoveryRepository discoveryRepository(Ref ref) => DiscoveryRepository();

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) => ChatRepository();

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  throw UnimplementedError('notificationRepositoryProvider must be overridden in main.dart');
}

@Riverpod(keepAlive: true)
LocationRepository locationRepository(Ref ref) => LocationRepository();

@Riverpod(keepAlive: true)
AiRepository aiRepository(Ref ref) => AiRepository();

// Module 4: Notifications (SQLite), Who Liked Me, Swipe History
@Riverpod(keepAlive: true)
ActivityRepository activityRepository(Ref ref) => ActivityRepository(
      dbHelper: DatabaseHelper.instance,
      discoveryRepository: ref.watch(discoveryRepositoryProvider),
      notificationRepository: ref.watch(notificationRepositoryProvider),
    );

@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(Ref ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/firebase_storage_service.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/location_service.dart';

// Provider cho SharedPreferences (sẽ override trong main.dart sau khi init)
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('preferencesServiceProvider must be overridden in main.dart');
});

// Provider cho Firebase Auth Service
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

// Provider cho Firestore Service
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// Provider cho Firebase Storage Service
final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});

// Provider cho Notification Service
// (override trong main.dart bằng instance đã init)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError(
      'notificationServiceProvider must be overridden in main.dart');
});

// Provider cho Location Service
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// StreamProvider theo dõi trạng thái Auth hiện tại
final authStateChangesProvider = StreamProvider((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});

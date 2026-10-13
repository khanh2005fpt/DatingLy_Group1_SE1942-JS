import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firebase_auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../data/services/firebase_storage_service.dart';

// StreamProvider hồ sơ cá nhân của người dùng hiện tại
final myProfileStreamProvider = StreamProvider<UserModel?>((ref) {
  final myId = ref.watch(authStateChangesProvider).value?.uid;
  final firestore = ref.watch(firestoreServiceProvider);

  if (myId == null) return Stream.value(null);
  return firestore.streamUserProfile(myId);
});

class ProfileViewModel {
  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;
  final FirebaseStorageService _storageService;

  ProfileViewModel({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
    required FirebaseStorageService storageService,
  })  : _firestoreService = firestoreService,
        _authService = authService,
        _storageService = storageService;

  Future<void> updateProfile({
    required String fullName,
    required int age,
    required String gender,
    required String bio,
    required List<String> tags,
    List<String>? avatarUrls,
  }) async {
    final myId = _authService.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    final existing = await _firestoreService.getUserProfile(myId);
    final updated = (existing ?? UserModel(id: myId)).copyWith(
      fullName: fullName,
      age: age,
      gender: gender,
      bio: bio,
      tags: tags,
      avatarUrls: avatarUrls ?? existing?.avatarUrls,
      updatedAt: DateTime.now(),
    );

    await _firestoreService.saveUserProfile(updated);
  }

  Future<String> uploadAvatar(XFile imageFile) async {
    final myId = _authService.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    final downloadUrl = await _storageService.uploadAvatar(
      userId: myId,
      imageFile: imageFile,
    );

    final existing = await _firestoreService.getUserProfile(myId);
    final currentList = List<String>.from(existing?.avatarUrls ?? []);
    if (currentList.isNotEmpty) {
      currentList[0] = downloadUrl;
    } else {
      currentList.add(downloadUrl);
    }

    await _firestoreService.saveUserProfile(
      (existing ?? UserModel(id: myId)).copyWith(avatarUrls: currentList),
    );

    return downloadUrl;
  }

  Future<String> uploadPhoto(XFile imageFile) async {
    final myId = _authService.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    final downloadUrl = await _storageService.uploadPhoto(
      userId: myId,
      imageFile: imageFile,
    );

    final existing = await _firestoreService.getUserProfile(myId);
    final currentList = List<String>.from(existing?.avatarUrls ?? []);
    currentList.add(downloadUrl);

    await _firestoreService.saveUserProfile(
      (existing ?? UserModel(id: myId)).copyWith(avatarUrls: currentList),
    );

    return downloadUrl;
  }
}

final profileViewModelProvider = Provider<ProfileViewModel>((ref) {
  return ProfileViewModel(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    storageService: ref.watch(firebaseStorageServiceProvider),
  );
});

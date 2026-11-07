import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/setting_repository.dart';

// StreamProvider hồ sơ cá nhân của người dùng hiện tại
final myProfileStreamProvider = StreamProvider<UserModel?>((ref) {
  final myId = ref.watch(authStateChangesProvider).value?.uid;
  final userRepo = ref.watch(userRepositoryProvider);

  if (myId == null) return Stream.value(null);
  return userRepo.streamUserProfile(myId);
});

class ProfileViewModel {
  final UserRepository _userRepo;
  final AuthRepository _authRepo;
  final SettingRepository _settingRepo;

  ProfileViewModel({
    required UserRepository userRepo,
    required AuthRepository authRepo,
    required SettingRepository settingRepo,
  })  : _userRepo = userRepo,
        _authRepo = authRepo,
        _settingRepo = settingRepo;

  Future<void> updateProfile({
    required String fullName,
    DateTime? birthDate,
    required int age,
    required String gender,
    String? orientation,
    required String bio,
    required List<String> tags,
    List<String>? avatarUrls,
    List<ProfilePrompt>? prompts,
  }) async {
    final myId = _authRepo.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    final existing = await _userRepo.getUserProfile(myId);
    final updated = (existing ?? UserModel(id: myId)).copyWith(
      fullName: fullName,
      birthDate: birthDate ?? existing?.birthDate,
      age: age,
      gender: gender,
      orientation: orientation ?? existing?.orientation,
      bio: bio,
      tags: tags,
      avatarUrls: avatarUrls ?? existing?.avatarUrls,
      prompts: prompts ?? existing?.prompts,
      onboardingCompleted: true,
      updatedAt: DateTime.now(),
    );

    await _userRepo.saveUserProfile(updated);
    await _settingRepo.cacheUserProfile(updated);
    await _settingRepo.setOnboardingCompleted(true);
  }

  Future<String> uploadAvatar(XFile imageFile) async {
    final myId = _authRepo.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    final downloadUrl = await _userRepo.uploadAvatar(
      userId: myId,
      imageFile: imageFile,
    );

    final existing = await _userRepo.getUserProfile(myId);
    final currentList = List<String>.from(existing?.avatarUrls ?? []);
    if (currentList.isNotEmpty) {
      currentList[0] = downloadUrl;
    } else {
      currentList.add(downloadUrl);
    }

    final updated = (existing ?? UserModel(id: myId)).copyWith(avatarUrls: currentList);
    await _userRepo.saveUserProfile(updated);
    await _settingRepo.cacheUserProfile(updated);

    return downloadUrl;
  }

  Future<String> uploadPhoto(XFile imageFile) async {
    final myId = _authRepo.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    final downloadUrl = await _userRepo.uploadPhoto(
      userId: myId,
      imageFile: imageFile,
    );

    final existing = await _userRepo.getUserProfile(myId);
    final currentList = List<String>.from(existing?.avatarUrls ?? []);
    currentList.add(downloadUrl);

    final updated = (existing ?? UserModel(id: myId)).copyWith(avatarUrls: currentList);
    await _userRepo.saveUserProfile(updated);
    await _settingRepo.cacheUserProfile(updated);

    return downloadUrl;
  }

  Future<String> uploadPhotoBytes(Uint8List bytes, {String folder = 'photos'}) async {
    final myId = _authRepo.currentUser?.uid;
    if (myId == null) throw Exception('Chưa đăng nhập');

    return await _userRepo.uploadBytes(
      userId: myId,
      bytes: bytes,
      folder: folder,
    );
  }
}

final profileViewModelProvider = Provider<ProfileViewModel>((ref) {
  return ProfileViewModel(
    userRepo: ref.watch(userRepositoryProvider),
    authRepo: ref.watch(authRepositoryProvider),
    settingRepo: ref.watch(settingRepositoryProvider),
  );
});


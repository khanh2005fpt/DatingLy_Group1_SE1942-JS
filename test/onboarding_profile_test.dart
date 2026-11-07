import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_prm/data/models/user_model.dart';
import 'package:project_prm/data/repositories/setting_repository.dart';

void main() {
  group('SettingRepository - Onboarding & User Cache Tests', () {
    test('isFirstTimeUser mặc định là true và lưu cập nhật được', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await SettingRepository.init();

      expect(repo.isFirstTimeUser, isTrue);

      await repo.setIsFirstTimeUser(false);
      expect(repo.isFirstTimeUser, isFalse);
    });

    test('onboardingCompleted mặc định là false và lưu cập nhật được', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await SettingRepository.init();

      expect(repo.onboardingCompleted, isFalse);

      await repo.setOnboardingCompleted(true);
      expect(repo.onboardingCompleted, isTrue);
    });

    test('Cache và đọc lại thông tin user cơ bản từ SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await SettingRepository.init();

      const user = UserModel(
        id: 'user_123',
        fullName: 'Nguyễn Văn A',
        age: 24,
        gender: 'Nam',
        orientation: 'serious',
        bio: 'Yêu thích du lịch và công nghệ.',
        tags: ['Du lịch', 'Âm nhạc', 'Game'],
        avatarUrls: ['https://example.com/avatar1.jpg'],
        onboardingCompleted: true,
      );

      await repo.cacheUserProfile(user);

      final cached = repo.getCachedUserProfile();
      expect(cached, isNotNull);
      expect(cached!.id, 'user_123');
      expect(cached.fullName, 'Nguyễn Văn A');
      expect(cached.age, 24);
      expect(cached.gender, 'Nam');
      expect(cached.orientation, 'serious');
      expect(cached.tags, containsAll(['Du lịch', 'Âm nhạc', 'Game']));
      expect(cached.avatarUrls, ['https://example.com/avatar1.jpg']);
      expect(cached.onboardingCompleted, isTrue);

      await repo.clearCachedUserProfile();
      expect(repo.getCachedUserProfile(), isNull);
    });
  });

  group('UserModel - Model & Serialization Tests', () {
    test('UserModel toJsonString và fromJsonString bảo toàn dữ liệu', () {
      final now = DateTime.now();
      final user = UserModel(
        id: 'u_test',
        email: 'test@datingly.app',
        phoneNumber: '+84901234567',
        fullName: 'Trần Thị B',
        birthDate: DateTime(2000, 5, 20),
        age: 26,
        gender: 'Nữ',
        orientation: 'long_term',
        bio: 'Tìm bạn tâm sự và cùng đi ăn kem 🍦',
        tags: ['Cà phê', 'Yoga'],
        avatarUrls: ['https://storage.firebase.com/img1.jpg'],
        onboardingCompleted: true,
        createdAt: now,
      );

      final jsonStr = user.toJsonString();
      final restored = UserModel.fromJsonString(jsonStr);

      expect(restored, isNotNull);
      expect(restored!.id, 'u_test');
      expect(restored.email, 'test@datingly.app');
      expect(restored.phoneNumber, '+84901234567');
      expect(restored.fullName, 'Trần Thị B');
      expect(restored.age, 26);
      expect(restored.gender, 'Nữ');
      expect(restored.orientation, 'long_term');
      expect(restored.tags, ['Cà phê', 'Yoga']);
      expect(restored.onboardingCompleted, isTrue);
    });

    test('mainAvatarUrl trả về ảnh đầu tiên hoặc chuỗi rỗng', () {
      const userEmpty = UserModel(id: '1');
      expect(userEmpty.mainAvatarUrl, '');

      const userWithAvatar = UserModel(
        id: '2',
        avatarUrls: ['https://test.com/photo1.jpg', 'https://test.com/photo2.jpg'],
      );
      expect(userWithAvatar.mainAvatarUrl, 'https://test.com/photo1.jpg');
    });
  });
}

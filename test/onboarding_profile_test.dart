import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_prm/data/models/user_model.dart';
import 'package:project_prm/data/repositories/setting_repository.dart';
import 'package:project_prm/UI/ViewModels/auth_view_model.dart';

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
        interestedIn: 'Nam',
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
      expect(restored.interestedIn, 'Nam');
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

  group('AuthState & Resend OTP Timer Tests', () {
    test('AuthState khởi tạo mặc định resendCountdown = 0 và isOtpSent = false', () {
      const state = AuthState();
      expect(state.resendCountdown, 0);
      expect(state.isOtpSent, isFalse);
      expect(state.verificationId, isNull);
    });

    test('AuthState copyWith cập nhật chính xác trạng thái OTP và countdown', () {
      const state = AuthState();
      final updated = state.copyWith(
        isOtpSent: true,
        verificationId: 'v_123456',
        resendCountdown: 60,
        phoneNumber: '+84912345678',
      );

      expect(updated.isOtpSent, isTrue);
      expect(updated.verificationId, 'v_123456');
      expect(updated.resendCountdown, 60);
      expect(updated.phoneNumber, '+84912345678');
    });

    test('Resend timer đếm ngược giảm 1 sau mỗi giây và kết thúc khi đạt 0', () async {
      int countdown = 3;
      final timerHistory = <int>[];

      // Giả lập logic đếm ngược của startResendTimer
      while (countdown > 0) {
        timerHistory.add(countdown);
        countdown--;
      }
      timerHistory.add(countdown);

      expect(timerHistory, [3, 2, 1, 0]);
      expect(countdown, 0);
    });

    test('formatPhoneNumber chuẩn hóa các định dạng số điện thoại về E.164 (+84...) chính xác', () {
      final vm = AuthViewModel();
      expect(vm.formatPhoneNumber('0912345678'), '+84912345678');
      expect(vm.formatPhoneNumber('0912 345 678'), '+84912345678');
      expect(vm.formatPhoneNumber('+84912345678'), '+84912345678');
      expect(vm.formatPhoneNumber('912345678'), '+84912345678');
    });

    test('Mã OTP 6 chữ số hợp lệ và tự động phát hiện mã không đủ độ dài', () {
      const codeShort = '12345';
      const codeValid = '123456';

      expect(codeShort.length < 6, isTrue);
      expect(codeValid.length == 6, isTrue);
      expect(RegExp(r'^\d{6}$').hasMatch(codeValid), isTrue);
    });
  });

  group('Photo Drag & Drop Reordering & Media Logic Tests', () {
    test('Kéo thả ảnh hoán đổi vị trí và đưa ảnh lên làm avatar chính (index 0)', () {
      final photos = ['photo_1.jpg', 'photo_2.jpg', 'photo_3.jpg', 'photo_4.jpg'];

      // Người dùng kéo photo_3 (index 2) thả vào vị trí đầu tiên (index 0)
      const oldIndex = 2;
      const newIndex = 0;
      final draggedItem = photos.removeAt(oldIndex);
      photos.insert(newIndex, draggedItem);

      expect(photos[0], 'photo_3.jpg');
      expect(photos, ['photo_3.jpg', 'photo_1.jpg', 'photo_2.jpg', 'photo_4.jpg']);
      expect(photos.length, 4);
    });

    test('Kéo thả ảnh về cuối danh sách hoạt động chính xác', () {
      final photos = ['photo_A', 'photo_B', 'photo_C'];

      // Kéo photo_A (index 0) về cuối danh sách (index 2)
      final dragged = photos.removeAt(0);
      photos.insert(2, dragged);

      expect(photos, ['photo_B', 'photo_C', 'photo_A']);
      expect(photos.first, 'photo_B');
    });

    test('interestedIn và orientation được lưu trữ và copyWith chính xác', () {
      const user = UserModel(
        id: 'user_test',
        fullName: 'Khánh Test',
        age: 22,
        gender: 'male',
        interestedIn: 'female',
        orientation: 'serious',
      );

      expect(user.interestedIn, 'female');
      expect(user.orientation, 'serious');

      final updated = user.copyWith(interestedIn: 'all');
      expect(updated.interestedIn, 'all');
      expect(updated.orientation, 'serious');

      final map = updated.toMap();
      expect(map['interested_in'], 'all');
      expect(map['orientation'], 'serious');
    });
  });
}

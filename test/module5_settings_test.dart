import 'package:flutter_test/flutter_test.dart';
import 'package:project_prm/data/models/report_model.dart';
import 'package:project_prm/data/repositories/setting_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Module 5 - ReportModel Unit Tests', () {
    test('toMap should convert fields correctly', () {
      const report = ReportModel(
        reporterId: 'user_a',
        reportedId: 'user_b',
        reason: 'Spam / Quảng cáo',
        description: 'Spam tin nhắn rác liên tục',
        screenshotUrl: 'https://example.com/screenshot.jpg',
      );

      final map = report.toMap();
      expect(map['reporter_id'], equals('user_a'));
      expect(map['reported_id'], equals('user_b'));
      expect(map['reason'], equals('Spam / Quảng cáo'));
      expect(map['description'], equals('Spam tin nhắn rác liên tục'));
      expect(map['screenshot_url'], equals('https://example.com/screenshot.jpg'));
      expect(map['status'], equals('pending'));
    });

    test('fromMap should construct object correctly', () {
      final now = DateTime(2026, 11, 7, 10, 0);
      final map = {
        'reporter_id': 'user_1',
        'reported_id': 'user_2',
        'reason': 'Hồ sơ giả mạo',
        'description': 'Ảnh không chính chủ',
        'screenshot_url': null,
        'created_at': now.toIso8601String(),
      };

      final report = ReportModel.fromMap(map, 'doc_123');
      expect(report.id, equals('doc_123'));
      expect(report.reporterId, equals('user_1'));
      expect(report.reportedId, equals('user_2'));
      expect(report.reason, equals('Hồ sơ giả mạo'));
      expect(report.description, equals('Ảnh không chính chủ'));
      expect(report.screenshotUrl, isNull);
      expect(report.createdAt, equals(now));
    });

    test('ReportReason enum has correct label mapping', () {
      expect(ReportReason.spam.label, equals('Spam / Quảng cáo'));
      expect(ReportReason.inappropriate.label, equals('Nội dung không phù hợp'));
      expect(ReportReason.fake.label, equals('Hồ sơ giả mạo'));
      expect(ReportReason.harassment.label, equals('Quấy rối / Bạo lực'));
      expect(ReportReason.underage.label, equals('Người dùng dưới tuổi vị thành niên'));
      expect(ReportReason.other.label, equals('Lý do khác'));
    });
  });

  group('Module 5 - SettingRepository Unit Tests', () {
    test('should save and retrieve keys matching assignment requirements', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await SettingRepository.init();

      // Test ghost_mode
      expect(service.ghostMode, isFalse);
      await service.setGhostMode(true);
      expect(service.ghostMode, isTrue);

      // Test dark_mode_theme
      expect(service.isDarkMode, isFalse);
      await service.setDarkMode(true);
      expect(service.isDarkMode, isTrue);

      // Test notification_enabled
      expect(service.notificationsEnabled, isTrue);
      await service.setNotificationsEnabled(false);
      expect(service.notificationsEnabled, isFalse);
    });

    test('should fallback to legacy cfg_ keys when present', () async {
      SharedPreferences.setMockInitialValues({
        'cfg_dark_mode': true,
        'cfg_ghost_mode': true,
        'cfg_notifications_enabled': false,
      });
      final service = await SettingRepository.init();

      expect(service.isDarkMode, isTrue);
      expect(service.notificationsEnabled, isFalse);
    });
  });
}


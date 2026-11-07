import 'dart:async';

/// Các tiện ích liên quan đến gửi OTP qua số điện thoại:
/// chuẩn hóa số, số demo và bộ đếm gửi lại mã.

/// Chuẩn hóa số điện thoại về định dạng E.164 (mặc định mã vùng +84).
String formatPhoneNumber(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'\s+|-'), '').trim();
  if (cleaned.startsWith('0')) {
    cleaned = '+84${cleaned.substring(1)}';
  } else if (!cleaned.startsWith('+')) {
    cleaned = '+84$cleaned';
  }
  return cleaned;
}

/// Số điện thoại thử nghiệm demo PRM393: bỏ qua SMS thật.
const demoPhoneNumbers = {'+84988888888', '+84123456789', '+84999999999'};

const demoVerificationId = 'demo_verification_id';

bool isDemoPhoneNumber(String formattedPhone) =>
    demoPhoneNumbers.contains(formattedPhone);

/// Bộ đếm ngược gửi lại mã OTP. Không phụ thuộc state/Riverpod để dễ test.
class OtpResendTimer {
  Timer? _timer;

  /// Bắt đầu đếm từ [seconds]; gọi [onTick] với giá trị còn lại (kết thúc ở 0).
  void start(int seconds, void Function(int remaining) onTick) {
    _timer?.cancel();
    var remaining = seconds;
    onTick(remaining);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        onTick(0);
      } else {
        onTick(remaining);
      }
    });
  }

  void cancel() => _timer?.cancel();
}

/// Chuyển mã lỗi FirebaseAuthException sang thông báo tiếng Việt thân thiện.
String mapFirebaseAuthError(String code) {
  switch (code) {
    case 'invalid-phone-number':
      return 'Số điện thoại không đúng định dạng. Vui lòng kiểm tra lại.';
    case 'invalid-verification-code':
      return 'Mã OTP không chính xác. Vui lòng thử lại.';
    case 'session-expired':
      return 'Mã OTP đã hết hiệu lực. Vui lòng nhấn gửi lại mã.';
    case 'quota-exceeded':
      return 'Hạn mức SMS của dịch vụ tạm thời vượt quá. Vui lòng thử lại sau.';
    case 'too-many-requests':
      return 'Bạn đã thử quá nhiều lần. Vui lòng đợi trong giây lát rồi thử lại.';
    case 'user-disabled':
      return 'Tài khoản của bạn đã bị tạm khóa.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Thông tin đăng nhập không chính xác.';
    case 'email-already-in-use':
      return 'Email này đã được sử dụng cho tài khoản khác.';
    case 'invalid-email':
      return 'Địa chỉ email không đúng định dạng.';
    case 'weak-password':
      return 'Mật khẩu quá yếu (yêu cầu ít nhất 6 ký tự).';
    case 'network-request-failed':
      return 'Không thể kết nối Internet. Vui lòng kiểm tra mạng.';
    default:
      return 'Lỗi xác thực ($code). Vui lòng thử lại.';
  }
}

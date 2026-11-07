import 'package:firebase_auth/firebase_auth.dart';
import 'data_helper.dart';

/// PhoneAuthRepository: Xác thực qua số điện thoại (OTP) và đăng nhập ẩn danh (chế độ demo)
class PhoneAuthRepository {
  final FirebaseAuth _auth = DataHelper().auth;

  // Gửi mã OTP qua số điện thoại (Firebase Phone Auth)
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException exception) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? resendToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      timeout: timeout,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
    );
  }

  // Đăng nhập bằng mã OTP người dùng nhập
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    return _auth.signInWithCredential(credential);
  }

  // Đăng nhập bằng credential tự động (Android auto-retrieval)
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  // Đăng nhập ẩn danh (dùng cho số điện thoại demo)
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();
}

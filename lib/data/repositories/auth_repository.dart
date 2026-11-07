import 'package:firebase_auth/firebase_auth.dart';
import 'data_helper.dart';

/// AuthRepository: Phiên đăng nhập hiện tại + đăng nhập/đăng ký Email (PRM393 MVVM Pattern).
/// Xác thực số điện thoại nằm ở [PhoneAuthRepository].
class AuthRepository {
  final FirebaseAuth _auth = DataHelper().auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng nhập bằng Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Đăng ký bằng Email & Password
  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

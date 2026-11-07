import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import 'data_helper.dart';
import 'photo_codec.dart';

/// UserRepository: Quản lý dữ liệu người dùng trên Firestore (PRM393 MVVM Pattern)
class UserRepository {
  final DataHelper _helper = DataHelper();

  // Lưu hoặc cập nhật hồ sơ người dùng
  Future<void> saveUserProfile(UserModel user) async {
    await _helper.usersCol.doc(user.id).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  // Lấy hồ sơ một lần
  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _helper.usersCol.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc);
  }

  // Lắng nghe hồ sơ thay đổi theo thời gian thực (Stream)
  Stream<UserModel?> streamUserProfile(String userId) {
    return _helper.usersCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // Cập nhật FCM token
  Future<void> updateFcmToken(String userId, String token) async {
    await _helper.usersCol
        .doc(userId)
        .set({'fcm_token': token}, SetOptions(merge: true));
  }

  // Cập nhật toạ độ vị trí
  Future<void> updateLocation(String userId, GeoPoint location) async {
    await _helper.usersCol
        .doc(userId)
        .set({'location': location}, SetOptions(merge: true));
  }

  // --- Ảnh hồ sơ ---
  // Không dùng Firebase Storage (cần gói Blaze). Ảnh được nén rồi lưu dạng data URI
  // (base64) trong `avatar_urls` của document users. Xem PhotoCodec.

  // Chuẩn bị ảnh đại diện (XFile) để lưu vào hồ sơ
  Future<String> uploadAvatar({
    required String userId,
    required XFile imageFile,
  }) async {
    return PhotoCodec.encode(await imageFile.readAsBytes());
  }

  // Chuẩn bị ảnh trang cá nhân (XFile) để lưu vào hồ sơ
  Future<String> uploadPhoto({
    required String userId,
    required XFile imageFile,
  }) async {
    return PhotoCodec.encode(await imageFile.readAsBytes());
  }

  // Chuẩn bị dữ liệu ảnh đã crop (Uint8List): nén nhỏ và trả về data URI.
  // [userId], [folder], [extension] giữ lại để tương thích chữ ký cũ.
  Future<String> uploadBytes({
    required String userId,
    required Uint8List bytes,
    required String folder, // 'avatars' hoặc 'photos'
    String extension = 'jpg',
  }) async {
    return PhotoCodec.encode(bytes);
  }
}

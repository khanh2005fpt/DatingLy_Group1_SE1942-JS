import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/report_model.dart';
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

  // ==================== SAFETY / BLOCK / REPORT ====================

  /// Gửi báo cáo vi phạm vào collection `reports`
  Future<void> submitReport(ReportModel report) async {
    await _helper.reportsCol.add(report.toMap());
  }

  /// Chặn người dùng: thêm targetId vào mảng blocked_users của myId
  Future<void> blockUser(String myId, String targetId) async {
    await _helper.usersCol.doc(myId).update({
      'blocked_users': FieldValue.arrayUnion([targetId]),
    });
  }

  /// Bỏ chặn người dùng: xoá targetId khỏi mảng blocked_users của myId
  Future<void> unblockUser(String myId, String targetId) async {
    await _helper.usersCol.doc(myId).update({
      'blocked_users': FieldValue.arrayRemove([targetId]),
    });
  }

  /// Lấy danh sách user bị chặn của myId (trả về `List<UserModel>`)
  Future<List<UserModel>> getBlockedUsers(String myId) async {
    final doc = await _helper.usersCol.doc(myId).get();
    if (!doc.exists || doc.data() == null) return [];
    final myProfile = UserModel.fromFirestore(doc);
    final blockedIds = myProfile.blockedUsers;
    if (blockedIds.isEmpty) return [];

    final List<UserModel> blockedList = [];
    for (final id in blockedIds) {
      final user = await getUserProfile(id);
      if (user != null) blockedList.add(user);
    }
    return blockedList;
  }

  /// Cập nhật trạng thái Ghost Mode trên Firestore
  Future<void> updateGhostMode(String userId, bool isGhost) async {
    await _helper.usersCol.doc(userId).set(
      {'ghost_mode': isGhost},
      SetOptions(merge: true),
    );
  }
}

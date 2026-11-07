import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import 'data_helper.dart';

/// UserRepository: Quản lý dữ liệu người dùng trên Firestore & Storage (PRM393 MVVM Pattern)
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

  // Upload ảnh đại diện (XFile)
  Future<String> uploadAvatar({
    required String userId,
    required XFile imageFile,
  }) async {
    final ext = imageFile.name.split('.').last.toLowerCase();
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _helper.storage.ref().child('avatars').child(userId).child(fileName);

    final bytes = await imageFile.readAsBytes();
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    return await task.ref.getDownloadURL();
  }

  // Upload ảnh trang cá nhân (XFile)
  Future<String> uploadPhoto({
    required String userId,
    required XFile imageFile,
  }) async {
    final ext = imageFile.name.split('.').last.toLowerCase();
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _helper.storage.ref().child('photos').child(userId).child(fileName);

    final bytes = await imageFile.readAsBytes();
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    return await task.ref.getDownloadURL();
  }

  // Upload dữ liệu ảnh đã qua crop & nén (Uint8List)
  Future<String> uploadBytes({
    required String userId,
    required Uint8List bytes,
    required String folder, // 'avatars' hoặc 'photos'
    String extension = 'jpg',
  }) async {
    final randomSuffix = Random().nextInt(10000);
    final fileName =
        '${folder.replaceAll('/', '')}_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix.$extension';
    final ref = _helper.storage.ref().child(folder).child(userId).child(fileName);

    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$extension'),
    );
    return await task.ref.getDownloadURL();
  }
}


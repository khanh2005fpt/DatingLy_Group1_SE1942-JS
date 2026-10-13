import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadAvatar({
    required String userId,
    required XFile imageFile,
  }) async {
    final fileExtension = imageFile.name.split('.').last.toLowerCase();
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final ref = _storage.ref().child('avatars').child(userId).child(fileName);

    final bytes = await imageFile.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$fileExtension'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  Future<String> uploadPhoto({
    required String userId,
    required XFile imageFile,
  }) async {
    final fileExtension = imageFile.name.split('.').last.toLowerCase();
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final ref = _storage.ref().child('photos').child(userId).child(fileName);

    final bytes = await imageFile.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$fileExtension'),
    );

    return await uploadTask.ref.getDownloadURL();
  }
}

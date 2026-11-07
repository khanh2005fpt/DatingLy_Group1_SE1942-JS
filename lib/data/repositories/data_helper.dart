import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Lớp DataHelper kết nối cơ sở dữ liệu và các dịch vụ đám mây (PRM393 MVVM Pattern)
class DataHelper {
  static final DataHelper _instance = DataHelper._internal();
  factory DataHelper() => _instance;
  DataHelper._internal();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Collection References
  CollectionReference<Map<String, dynamic>> get usersCol =>
      firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get swipesCol =>
      firestore.collection('swipes');

  CollectionReference<Map<String, dynamic>> get matchesCol =>
      firestore.collection('matches');

  CollectionReference<Map<String, dynamic>> get messagesCol =>
      firestore.collection('messages');
}


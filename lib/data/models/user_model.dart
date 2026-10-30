import 'package:cloud_firestore/cloud_firestore.dart';

/// User Model trong kiến trúc MVVM
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final int age;
  final String gender;
  final String bio;
  final List<String> tags;
  final List<String> avatarUrls;
  final String? fcmToken;
  final bool ghostMode;
  final List<String> blockedUsers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.email = '',
    this.fullName = '',
    this.age = 18,
    this.gender = 'other',
    this.bio = '',
    this.tags = const [],
    this.avatarUrls = const [],
    this.fcmToken,
    this.ghostMode = false,
    this.blockedUsers = const [],
    this.createdAt,
    this.updatedAt,
  });

  String get mainAvatarUrl =>
      avatarUrls.isNotEmpty ? avatarUrls.first : '';

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    int? age,
    String? gender,
    String? bio,
    List<String>? tags,
    List<String>? avatarUrls,
    String? fcmToken,
    bool? ghostMode,
    List<String>? blockedUsers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      tags: tags ?? this.tags,
      avatarUrls: avatarUrls ?? this.avatarUrls,
      fcmToken: fcmToken ?? this.fcmToken,
      ghostMode: ghostMode ?? this.ghostMode,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'bio': bio,
      'tags': tags,
      'avatar_urls': avatarUrls,
      if (fcmToken != null) 'fcm_token': fcmToken,
      'ghost_mode': ghostMode,
      'blocked_users': blockedUsers,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return UserModel(
      id: docId,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? map['fullName'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 18,
      gender: map['gender'] as String? ?? 'other',
      bio: map['bio'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      avatarUrls: (map['avatar_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (map['avatarUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fcmToken: map['fcm_token'] as String?,
      ghostMode: map['ghost_mode'] as bool? ?? false,
      blockedUsers: (map['blocked_users'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Câu hỏi + câu trả lời hiển thị trên hồ sơ (prompt).
class ProfilePrompt {
  final String question;
  final String answer;

  const ProfilePrompt({required this.question, required this.answer});

  Map<String, dynamic> toMap() => {'question': question, 'answer': answer};

  static ProfilePrompt? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final q = raw['question']?.toString() ?? '';
    final a = raw['answer']?.toString() ?? '';
    if (q.isEmpty || a.isEmpty) return null;
    return ProfilePrompt(question: q, answer: a);
  }
}

/// User Model trong kiến trúc MVVM
class UserModel {
  final String id;
  final String email;
  final String? phoneNumber;
  final String fullName;
  final DateTime? birthDate;
  final int age;
  final String gender;
  final String interestedIn; // 'Nam' | 'Nữ' | 'all' (Giới tính muốn tìm kiếm / hẹn hò)
  final String orientation; // Định hướng hẹn hò / mối quan hệ
  final String bio;
  final List<String> tags;
  final List<String> avatarUrls;
  final bool onboardingCompleted;
  final String? fcmToken;
  final GeoPoint? location;
  final List<ProfilePrompt> prompts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.email = '',
    this.phoneNumber,
    this.fullName = '',
    this.birthDate,
    this.age = 18,
    this.gender = 'other',
    this.interestedIn = 'all',
    this.orientation = '',
    this.bio = '',
    this.tags = const [],
    this.avatarUrls = const [],
    this.onboardingCompleted = false,
    this.fcmToken,
    this.location,
    this.prompts = const [],
    this.createdAt,
    this.updatedAt,
  });

  String get mainAvatarUrl => avatarUrls.isNotEmpty ? avatarUrls.first : '';

  UserModel copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? fullName,
    DateTime? birthDate,
    int? age,
    String? gender,
    String? interestedIn,
    String? orientation,
    String? bio,
    List<String>? tags,
    List<String>? avatarUrls,
    bool? onboardingCompleted,
    String? fcmToken,
    GeoPoint? location,
    List<ProfilePrompt>? prompts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      orientation: orientation ?? this.orientation,
      bio: bio ?? this.bio,
      tags: tags ?? this.tags,
      avatarUrls: avatarUrls ?? this.avatarUrls,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      fcmToken: fcmToken ?? this.fcmToken,
      location: location ?? this.location,
      prompts: prompts ?? this.prompts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'full_name': fullName,
      if (birthDate != null) 'birth_date': Timestamp.fromDate(birthDate!),
      'age': age,
      'gender': gender,
      'interested_in': interestedIn,
      'orientation': orientation,
      'bio': bio,
      'tags': tags,
      'avatar_urls': avatarUrls,
      'onboarding_completed': onboardingCompleted,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (location != null) 'location': location,
      // Luôn ghi (kể cả rỗng) để xóa hết prompt thì Firestore merge cũng cập nhật.
      'prompts': prompts.map((p) => p.toMap()).toList(),
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final fullName = map['full_name'] as String? ?? map['fullName'] as String? ?? '';
    final hasCompleted = map['onboarding_completed'] as bool? ?? fullName.isNotEmpty;

    return UserModel(
      id: docId,
      email: map['email'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? map['phoneNumber'] as String?,
      fullName: fullName,
      birthDate: parseDate(map['birth_date']),
      age: (map['age'] as num?)?.toInt() ?? 18,
      gender: map['gender'] as String? ?? 'other',
      interestedIn: map['interested_in'] as String? ??
          map['interestedIn'] as String? ??
          'all',
      orientation: map['orientation'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      tags:
          (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      avatarUrls:
          (map['avatar_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (map['avatarUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      onboardingCompleted: hasCompleted,
      fcmToken: map['fcm_token'] as String?,
      location: map['location'] is GeoPoint
          ? map['location'] as GeoPoint
          : null,
      prompts:
          (map['prompts'] as List<dynamic>?)
              ?.map(ProfilePrompt.tryParse)
              .whereType<ProfilePrompt>()
              .toList() ??
          [],
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }

  // --- Local Cache Serialization (SharedPreferences) ---
  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'email': email,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'birth_date': birthDate?.toIso8601String(),
      'age': age,
      'gender': gender,
      'interested_in': interestedIn,
      'orientation': orientation,
      'bio': bio,
      'tags': tags,
      'avatar_urls': avatarUrls,
      'onboarding_completed': onboardingCompleted,
      'fcm_token': fcmToken,
      if (location != null)
        'location': {
          'latitude': location!.latitude,
          'longitude': location!.longitude,
        },
      'prompts': prompts.map((p) => p.toMap()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJsonMap());

  factory UserModel.fromJsonMap(Map<String, dynamic> json) {
    GeoPoint? parseGeo(dynamic loc) {
      if (loc is Map && loc['latitude'] != null && loc['longitude'] != null) {
        return GeoPoint(
          (loc['latitude'] as num).toDouble(),
          (loc['longitude'] as num).toDouble(),
        );
      }
      return null;
    }

    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      fullName: json['full_name'] as String? ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      age: (json['age'] as num?)?.toInt() ?? 18,
      gender: json['gender'] as String? ?? 'other',
      interestedIn: json['interested_in']?.toString() ??
          json['interestedIn']?.toString() ??
          'all',
      orientation: json['orientation'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      avatarUrls: (json['avatar_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      fcmToken: json['fcm_token'] as String?,
      location: parseGeo(json['location']),
      prompts: (json['prompts'] as List<dynamic>?)
              ?.map(ProfilePrompt.tryParse)
              .whereType<ProfilePrompt>()
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  static UserModel? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return UserModel.fromJsonMap(map);
      }
    } catch (_) {}
    return null;
  }
}


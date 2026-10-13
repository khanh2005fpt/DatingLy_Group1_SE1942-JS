import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class MatchModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime? createdAt;
  final UserModel? otherProfile;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  const MatchModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.createdAt,
    this.otherProfile,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  String getOtherUserId(String myId) => user1Id == myId ? user2Id : user1Id;

  MatchModel copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
    UserModel? otherProfile,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return MatchModel(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      createdAt: createdAt ?? this.createdAt,
      otherProfile: otherProfile ?? this.otherProfile,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unread_count': unreadCount,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map, String docId,
      {UserModel? otherProfile}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return MatchModel(
      id: docId,
      user1Id: map['user1_id'] as String? ?? '',
      user2Id: map['user2_id'] as String? ?? '',
      createdAt: parseDate(map['created_at']),
      lastMessage: map['last_message'] as String?,
      lastMessageTime: parseDate(map['last_message_time']),
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      otherProfile: otherProfile,
    );
  }
}

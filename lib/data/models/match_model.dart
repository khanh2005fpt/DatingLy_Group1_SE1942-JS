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
  final String? lastSenderId;
  final int unreadCount; // Số tin chưa đọc của người dùng hiện tại

  const MatchModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.createdAt,
    this.otherProfile,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCount = 0,
  });

  /// Id cố định theo cặp user: 2 người quẹt cùng lúc cũng chỉ tạo 1 match.
  static String idFor(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String getOtherUserId(String myId) => user1Id == myId ? user2Id : user1Id;

  /// Match chưa có tin nhắn nào -> hiển thị ở hàng "Tương hợp mới"
  bool get isNewMatch => lastSenderId == null;

  /// Thời điểm dùng để sắp xếp danh sách (tin mới nhất hoặc lúc match)
  DateTime get sortTime =>
      lastMessageTime ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  MatchModel copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
    UserModel? otherProfile,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastSenderId,
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
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'users': [user1Id, user2Id],
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'last_sender_id': lastSenderId,
      'unread_counts': {user1Id: 0, user2Id: 0},
    };
  }

  /// [myId] dùng để lấy số tin chưa đọc của mình trong map `unread_counts`.
  factory MatchModel.fromMap(Map<String, dynamic> map, String docId,
      {String? myId, UserModel? otherProfile}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final unreadCounts = map['unread_counts'] as Map<String, dynamic>?;

    return MatchModel(
      id: docId,
      user1Id: map['user1_id'] as String? ?? '',
      user2Id: map['user2_id'] as String? ?? '',
      createdAt: parseDate(map['created_at']),
      lastMessage: map['last_message'] as String?,
      lastMessageTime: parseDate(map['last_message_time']),
      lastSenderId: map['last_sender_id'] as String?,
      unreadCount: (unreadCounts?[myId] as num?)?.toInt() ?? 0,
      otherProfile: otherProfile,
    );
  }
}

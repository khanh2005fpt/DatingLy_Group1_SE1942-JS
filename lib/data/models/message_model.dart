import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final String messageType; // 'text' | 'image' | 'prompt'
  final bool isRead;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.isRead = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'match_id': matchId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? date;
    final created = map['created_at'];
    if (created is Timestamp) {
      date = created.toDate();
    } else if (created is String) {
      date = DateTime.tryParse(created);
    }

    return MessageModel(
      id: docId,
      matchId: map['match_id'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'text',
      isRead: map['is_read'] as bool? ?? false,
      createdAt: date ?? DateTime.now(),
    );
  }
}

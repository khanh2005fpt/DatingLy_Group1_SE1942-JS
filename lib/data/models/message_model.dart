import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  static const String typeText = 'text';
  static const String typeImage = 'image';

  final String id;
  final String matchId;
  final String senderId;
  final String content; // Nội dung text, hoặc URL ảnh nếu messageType = 'image'
  final String messageType; // 'text' | 'image' | 'prompt'
  final bool isRead;
  final DateTime? createdAt;

  /// true khi tin nhắn mới ghi ở máy, server chưa xác nhận (trạng thái "Đang gửi")
  final bool isPending;

  const MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    this.messageType = typeText,
    this.isRead = false,
    this.createdAt,
    this.isPending = false,
  });

  bool get isImage => messageType == typeImage;

  /// Nội dung ngắn gọn để hiển thị ở danh sách chat / thông báo
  String get preview => isImage ? '📷 Ảnh' : content;

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

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId,
      {bool isPending = false}) {
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
      messageType: map['message_type'] as String? ?? typeText,
      isRead: map['is_read'] as bool? ?? false,
      // serverTimestamp chưa có giá trị khi tin còn pending -> tạm dùng giờ máy
      createdAt: date ?? DateTime.now(),
      isPending: isPending,
    );
  }

  factory MessageModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return MessageModel.fromMap(
      doc.data() ?? {},
      doc.id,
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  // ==================== SQLite cache ====================

  Map<String, Object?> toCacheMap() {
    return {
      'id': id,
      'match_id': matchId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'is_read': isRead ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  factory MessageModel.fromCacheMap(Map<String, Object?> map) {
    return MessageModel(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      messageType: map['message_type'] as String,
      isRead: (map['is_read'] as int) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

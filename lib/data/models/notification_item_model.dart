import 'package:flutter/material.dart';

class NotificationItemModel {
  final int? id;
  final String notificationId;
  final String title;
  final String body;
  final String type; // 'match', 'like', 'message', 'system'
  final String? data; // extra json or string
  final String? route; // route navigation path
  final DateTime createdAt;
  final bool isRead;

  const NotificationItemModel({
    this.id,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.route,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationItemModel copyWith({
    int? id,
    String? notificationId,
    String? title,
    String? body,
    String? type,
    String? data,
    String? route,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'notification_id': notificationId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'route': route,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_read': isRead ? 1 : 0,
    };
  }

  factory NotificationItemModel.fromMap(Map<String, dynamic> map) {
    return NotificationItemModel(
      id: map['id'] as int?,
      notificationId: map['notification_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'system',
      data: map['data'] as String?,
      route: map['route'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      isRead: (map['is_read'] as int? ?? 0) == 1,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  IconData get iconData {
    switch (type) {
      case 'match':
        return Icons.favorite_rounded;
      case 'like':
        return Icons.thumb_up_alt_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'system':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'match':
        return const Color(0xFFFD297B); // Primary pink
      case 'like':
        return const Color(0xFFFFB300); // Gold/amber
      case 'message':
        return const Color(0xFF2979FF); // Blue
      case 'system':
      default:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  String get typeLabel {
    switch (type) {
      case 'match':
        return 'Tương hợp';
      case 'like':
        return 'Lượt thích';
      case 'message':
        return 'Tin nhắn';
      case 'system':
      default:
        return 'Hệ thống';
    }
  }
}

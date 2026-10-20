import 'package:flutter/material.dart';

class SwipeHistoryModel {
  final int? id;
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;
  final int? targetUserAge;
  final String? targetUserBio;
  final String action; // 'like', 'nope', 'superlike'
  final DateTime timestamp;

  const SwipeHistoryModel({
    this.id,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    this.targetUserAge,
    this.targetUserBio,
    required this.action,
    required this.timestamp,
  });

  SwipeHistoryModel copyWith({
    int? id,
    String? targetUserId,
    String? targetUserName,
    String? targetUserAvatar,
    int? targetUserAge,
    String? targetUserBio,
    String? action,
    DateTime? timestamp,
  }) {
    return SwipeHistoryModel(
      id: id ?? this.id,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      targetUserAvatar: targetUserAvatar ?? this.targetUserAvatar,
      targetUserAge: targetUserAge ?? this.targetUserAge,
      targetUserBio: targetUserBio ?? this.targetUserBio,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'target_user_id': targetUserId,
      'target_user_name': targetUserName,
      'target_user_avatar': targetUserAvatar,
      'target_user_age': targetUserAge,
      'target_user_bio': targetUserBio,
      'action': action,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SwipeHistoryModel.fromMap(Map<String, dynamic> map) {
    return SwipeHistoryModel(
      id: map['id'] as int?,
      targetUserId: map['target_user_id'] as String? ?? '',
      targetUserName: map['target_user_name'] as String? ?? 'Người dùng',
      targetUserAvatar: map['target_user_avatar'] as String?,
      targetUserAge: map['target_user_age'] as int?,
      targetUserBio: map['target_user_bio'] as String?,
      action: map['action'] as String? ?? 'nope',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
    );
  }

  bool get isLike => action == 'like';
  bool get isSuperLike => action == 'superlike';
  bool get isNope => action == 'nope';

  String get actionLabel {
    switch (action) {
      case 'like':
        return 'Đã thích';
      case 'superlike':
        return 'Super Like';
      case 'nope':
      default:
        return 'Bỏ qua';
    }
  }

  Color get actionColor {
    switch (action) {
      case 'like':
        return const Color(0xFF4CAF50); // Green
      case 'superlike':
        return const Color(0xFF03A9F4); // Blue
      case 'nope':
      default:
        return const Color(0xFFE53935); // Red
    }
  }

  IconData get actionIcon {
    switch (action) {
      case 'like':
        return Icons.favorite_rounded;
      case 'superlike':
        return Icons.star_rounded;
      case 'nope':
      default:
        return Icons.close_rounded;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

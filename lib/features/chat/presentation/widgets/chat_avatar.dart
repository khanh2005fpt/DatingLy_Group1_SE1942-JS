import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Ảnh đại diện tròn, không có ảnh thì hiện chữ cái đầu của tên.
class ChatAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const ChatAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      foregroundImage: hasUrl ? NetworkImage(url!) : null,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

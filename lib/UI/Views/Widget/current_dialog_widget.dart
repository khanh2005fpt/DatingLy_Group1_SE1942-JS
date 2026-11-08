import 'package:flutter/material.dart';
import '../../app_colors.dart';

/// CurrentDialogWidget: Hộp thoại xác nhận / thông báo dùng chung (PRM393 MVVM Pattern)
class CurrentDialogWidget extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const CurrentDialogWidget({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Xác nhận',
    this.cancelText = 'Hủy',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CurrentDialogWidget(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Text(
        message,
        style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: Text(
            cancelText,
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onConfirm,
          child: Text(confirmText),
        ),
      ],
    );
  }
}


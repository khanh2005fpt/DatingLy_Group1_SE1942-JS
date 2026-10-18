import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/message_model.dart';
import '../utils/chat_time_format.dart';

/// 1 tin nhắn trong khung chat: text, emoji lớn hoặc ảnh.
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  /// Hiện dòng trạng thái "Đang gửi / Đã gửi / Đã xem" (chỉ tin cuối của mình)
  final bool showStatusLabel;

  /// Tin kế tiếp cùng người gửi -> thu hẹp khoảng cách cho gọn
  final bool groupedWithNext;
  final VoidCallback? onImageTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showStatusLabel = false,
    this.groupedWithNext = false,
    this.onImageTap,
  });

  static bool _isEmojiRune(int r) =>
      r >= 0x1F000 || // Mặt cười, biểu tượng, cờ...
      (r >= 0x2190 && r <= 0x2BFF) || // Mũi tên, ký hiệu, ❤ ☕ ✨...
      r == 0x200D || // Zero width joiner
      r == 0xFE0F || // Variation selector
      r == 0x20E3 ||
      r == 0x20; // Khoảng trắng

  /// Tin chỉ gồm 1-3 emoji -> hiển thị cỡ lớn, không có bong bóng
  bool get _isBigEmoji =>
      !message.isImage &&
      message.content.characters.length <= 3 &&
      message.content.runes.every(_isEmojiRune);

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    Widget content;
    if (message.isImage) {
      content = _buildImage(context);
    } else if (_isBigEmoji) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(message.content, style: const TextStyle(fontSize: 44)),
      );
    } else {
      content = _buildTextBubble(context);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: groupedWithNext ? 2 : 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Opacity(
              opacity: message.isPending ? 0.7 : 1,
              child: content,
            ),
          ),
          if (showStatusLabel) _buildStatusLabel(),
        ],
      ),
    );
  }

  Widget _buildTextBubble(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );
    final textColor = isMe ? Colors.white : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 6),
      decoration: BoxDecoration(
        gradient: isMe ? AppColors.primaryGradient : null,
        color: isMe ? null : scheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(message.content,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.3)),
          _buildMeta(isMe ? Colors.white70 : scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return GestureDetector(
      onTap: onImageTap,
      child: Hero(
        tag: 'chat_image_${message.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Image.network(
                message.content,
                width: 220,
                height: 260,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 220,
                    height: 260,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stack) => Container(
                  width: 220,
                  height: 160,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _buildMeta(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Giờ gửi + icon trạng thái (tin của mình)
  Widget _buildMeta(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ChatTimeFormat.clock(message.createdAt ?? DateTime.now()),
          style: TextStyle(fontSize: 10.5, color: color),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            message.isPending
                ? Icons.schedule
                : message.isRead
                    ? Icons.done_all
                    : Icons.done,
            size: 14,
            color: message.isRead && !message.isPending
                ? Colors.lightBlueAccent
                : color,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusLabel() {
    final String label;
    final Color color;
    if (message.isPending) {
      label = 'Đang gửi...';
      color = Colors.grey;
    } else if (message.isRead) {
      label = 'Đã xem';
      color = Colors.blue;
    } else {
      label = 'Đã gửi';
      color = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 4),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

/// Ngăn cách ngày trong khung chat
class ChatDateDivider extends StatelessWidget {
  final DateTime date;

  const ChatDateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ChatTimeFormat.dayLabel(date),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Xem ảnh toàn màn hình, phóng to bằng 2 ngón tay
class ChatImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const ChatImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Hero(tag: heroTag, child: Image.network(imageUrl)),
        ),
      ),
    );
  }
}

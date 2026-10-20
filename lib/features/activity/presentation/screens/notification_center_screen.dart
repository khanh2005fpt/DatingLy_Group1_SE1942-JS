import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/notification_item_model.dart';
import '../viewmodels/notification_view_model.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationViewModelProvider);
    final viewModel = ref.read(notificationViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Thông báo',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount} mới',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await viewModel.markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đánh dấu tất cả là đã đọc'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'clear_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Xóa tất cả thông báo?'),
                    content: const Text(
                      'Tất cả lịch sử thông báo trong SQLite sẽ bị xóa vĩnh viễn.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Xóa hết'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await viewModel.clearAll();
                }
              } else if (value == 'test_notification') {
                _showTestNotificationSheet(context, viewModel);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Text('Đánh dấu tất cả đã đọc'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_notification',
                child: Row(
                  children: [
                    Icon(Icons.notification_add, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Text('Tạo thông báo thử nghiệm'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Xóa toàn bộ'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _FilterTabsRow(
            currentFilter: state.currentFilter,
            onFilterChanged: viewModel.setFilter,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.notifications.isEmpty
              ? _buildEmptyState(context, viewModel)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: viewModel.loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.notifications.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 76, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      final item = state.notifications[index];
                      return _NotificationTile(
                        item: item,
                        onTap: () => _handleItemClick(context, item, viewModel),
                        onDismissed: () {
                          if (item.id != null) {
                            viewModel.deleteNotification(item.id!);
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  void _handleItemClick(
    BuildContext context,
    NotificationItemModel item,
    NotificationViewModel viewModel,
  ) {
    if (item.id != null && !item.isRead) {
      viewModel.markAsRead(item.id!);
    }

    if (item.route != null && item.route!.isNotEmpty) {
      context.push(item.route!);
    } else if (item.type == 'match' || item.type == 'message') {
      context.push('/matches');
    } else if (item.type == 'like') {
      context.push('/who-liked-me');
    } else {
      // Hiển thị dialog chi tiết cho thông báo hệ thống
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(item.iconData, color: item.iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.body, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              Text(
                'Thời gian: ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')} - ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    NotificationViewModel viewModel,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không có thông báo nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Khi có ai đó thích bạn, tương hợp mới hoặc tin nhắn đến, bạn sẽ nhận được thông báo tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_alert_rounded, size: 18),
              label: const Text('Thử nghiệm gửi thông báo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _showTestNotificationSheet(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestNotificationSheet(
    BuildContext context,
    NotificationViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gửi thông báo thử nghiệm (SQLite + Push)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn loại thông báo để kiểm thử tính năng lưu trữ SQLite và bắn Push Notification:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFCE4EC),
                child: Icon(Icons.favorite, color: AppColors.primary),
              ),
              title: const Text('Thông báo Match mới 🎉'),
              subtitle: const Text('Bạn và Linh Đan đã thích nhau!'),
              onTap: () {
                Navigator.pop(ctx);
                viewModel.addDemoNotification(
                  type: 'match',
                  title: 'Tương hợp mới! 🎉',
                  body: 'Bạn và Linh Đan vừa tương hợp với nhau. Hãy chào hỏi ngay!',
                  route: '/matches',
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF8E1),
                child: Icon(Icons.thumb_up, color: Color(0xFFFFB300)),
              ),
              title: const Text('Thông báo ai đó đã Thích bạn ⭐'),
              subtitle: const Text('Một người vừa quẹt phải hồ sơ của bạn'),
              onTap: () {
                Navigator.pop(ctx);
                viewModel.addDemoNotification(
                  type: 'like',
                  title: 'Ai đó đã thích bạn! ⭐',
                  body: 'Một hồ sơ hấp dẫn vừa bấm Like bạn. Mở DatingLy Gold để xem!',
                  route: '/who-liked-me',
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.chat_bubble, color: Color(0xFF2979FF)),
              ),
              title: const Text('Tin nhắn mới 💬'),
              subtitle: const Text('Hương: "Chào bạn, hôm nay thế nào?"'),
              onTap: () {
                Navigator.pop(ctx);
                viewModel.addDemoNotification(
                  type: 'message',
                  title: 'Hương vừa nhắn tin',
                  body: 'Chào bạn, hôm nay của bạn thế nào? 😊',
                  route: '/matches',
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3E5F5),
                child: Icon(Icons.info_outline, color: Color(0xFF9C27B0)),
              ),
              title: const Text('Thông báo hệ thống 🔔'),
              subtitle: const Text('Chào mừng bạn đến với DatingLy!'),
              onTap: () {
                Navigator.pop(ctx);
                viewModel.addDemoNotification(
                  type: 'system',
                  title: 'Chào mừng thành viên mới!',
                  body: 'Hoàn thiện hồ sơ để tăng 80% cơ hội tìm thấy người ấy nhé!',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabsRow extends StatelessWidget {
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  const _FilterTabsRow({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'key': 'all', 'label': 'Tất cả'},
      {'key': 'match', 'label': 'Tương hợp 💖'},
      {'key': 'like', 'label': 'Lượt thích ⭐'},
      {'key': 'message', 'label': 'Tin nhắn 💬'},
      {'key': 'system', 'label': 'Hệ thống 🔔'},
    ];

    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = currentFilter == f['key'];

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onFilterChanged(f['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItemModel item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notif_${item.id ?? item.notificationId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red[600],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: item.isRead ? Colors.white : const Color(0xFFF9F1F5),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.iconData,
                        color: item.iconColor,
                        size: 24,
                      ),
                    ),
                    if (!item.isRead)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: item.isRead ? Colors.grey : AppColors.primary,
                              fontWeight:
                                  item.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: item.isRead
                              ? Colors.black54
                              : const Color(0xFF2C3E50),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: item.iconColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

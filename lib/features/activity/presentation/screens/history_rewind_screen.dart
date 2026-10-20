import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/swipe_history_model.dart';
import '../viewmodels/swipe_history_view_model.dart';

class HistoryRewindScreen extends ConsumerWidget {
  const HistoryRewindScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swipeHistoryViewModelProvider);
    final viewModel = ref.read(swipeHistoryViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Lịch sử & Hoàn tác',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới lịch sử',
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: viewModel.loadHistory,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'clear_history') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Xóa toàn bộ lịch sử?'),
                    content: const Text(
                      'Thao tác này sẽ xóa cache các lượt quẹt trong SQLite.',
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
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await viewModel.clearHistory();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_history',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Xóa lịch sử cache'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
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
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: viewModel.loadHistory,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // Top Rewind Hero: Nút hoàn tác lượt quẹt gần nhất
                  if (state.lastSwipe != null) ...[
                    _LastSwipeRewindCard(
                      lastSwipe: state.lastSwipe!,
                      isRewinding: state.isRewinding,
                      onRewind: () async {
                        final rewound = await viewModel.rewindLastSwipe();
                        if (rewound != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF2E7D32),
                              content: Row(
                                children: [
                                  const Icon(Icons.undo, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Đã hoàn tác lượt quẹt với ${rewound.targetUserName}! Thẻ đã sẵn sàng xuất hiện lại.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'DANH SÁCH LỊCH SỬ GẦN ĐÂY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],

                  // Danh sách các lượt quẹt từ SQLite
                  if (state.history.isEmpty)
                    _buildEmptyState(context)
                  else
                    ...state.history.map(
                      (item) => _SwipeHistoryTile(
                        item: item,
                        onRewind: () async {
                          final success = await viewModel.rewindSwipe(item);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã hoàn tác lượt quẹt với ${item.targetUserName}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 48,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có lịch sử quẹt nào',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mỗi khi bạn thích hoặc bỏ qua một người ở màn hình Khám phá, dữ liệu sẽ được lưu vào SQLite để bạn có thể xem lại và hoàn tác.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.style_outlined, color: Colors.white),
              label: const Text('Bắt đầu quẹt thẻ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => context.go('/discovery'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastSwipeRewindCard extends StatelessWidget {
  final SwipeHistoryModel lastSwipe;
  final bool isRewinding;
  final VoidCallback onRewind;

  const _LastSwipeRewindCard({
    required this.lastSwipe,
    required this.isRewinding,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB300),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  color: Colors.black87,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LƯỢT QUẸT GẦN NHẤT',
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: (lastSwipe.targetUserAvatar != null &&
                        lastSwipe.targetUserAvatar!.isNotEmpty)
                    ? NetworkImage(lastSwipe.targetUserAvatar!)
                    : null,
                backgroundColor: Colors.white24,
                child: lastSwipe.targetUserAvatar == null
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lastSwipe.targetUserName}${lastSwipe.targetUserAge != null ? ', ${lastSwipe.targetUserAge}' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lastSwipe.actionColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: lastSwipe.actionColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                lastSwipe.actionIcon,
                                size: 11,
                                color: lastSwipe.actionColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lastSwipe.actionLabel,
                                style: TextStyle(
                                  color: lastSwipe.actionColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lastSwipe.timeAgo,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: isRewinding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Hoàn tác'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isRewinding ? null : onRewind,
              ),
            ],
          ),
        ],
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
      {'key': 'like', 'label': 'Đã thích 💖'},
      {'key': 'superlike', 'label': 'Super Like ⭐'},
      {'key': 'nope', 'label': 'Đã bỏ qua ❌'},
    ];

    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = currentFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f['label']!),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                backgroundColor: Colors.grey[100],
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (_) => onFilterChanged(f['key']!),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SwipeHistoryTile extends StatelessWidget {
  final SwipeHistoryModel item;
  final VoidCallback onRewind;

  const _SwipeHistoryTile({
    required this.item,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = item.targetUserAvatar;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            backgroundColor: Colors.grey[200],
            child: avatar == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.targetUserName}${item.targetUserAge != null ? ', ${item.targetUserAge}' : ''}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.actionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.actionIcon, size: 12, color: item.actionColor),
                          const SizedBox(width: 4),
                          Text(
                            item.actionLabel,
                            style: TextStyle(
                              color: item.actionColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.timeAgo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hoàn tác thẻ này',
            icon: const Icon(Icons.undo_rounded, color: Colors.grey),
            onPressed: onRewind,
          ),
        ],
      ),
    );
  }
}

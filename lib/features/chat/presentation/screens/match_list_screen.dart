import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/match_model.dart';
import '../utils/chat_time_format.dart';
import '../viewmodels/chat_view_model.dart';
import '../widgets/chat_avatar.dart';

class MatchListScreen extends ConsumerWidget {
  const MatchListScreen({super.key});

  static String _displayName(MatchModel match) {
    final name = match.otherProfile?.fullName ?? '';
    return name.isNotEmpty ? name : 'Người ẩn danh';
  }

  Future<void> _openChat(BuildContext context, MatchModel match) async {
    final profile = match.otherProfile;
    await context.push(
      '/chat/${match.id}',
      extra: {
        'otherUserName': profile?.fullName,
        'otherAvatarUrl': profile?.mainAvatarUrl,
        'otherBio': profile?.bio,
        'otherTags': profile?.tags ?? <String>[],
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final myId = ref.watch(authStateChangesProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/discovery'),
        ),
      ),
      body: matchesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Lỗi tải danh sách: $err'),
          ),
        ),
        data: (matches) {
          if (matches.isEmpty) return _buildEmpty(context);

          final newMatches = matches.where((m) => m.isNewMatch).toList();
          final conversations = matches.where((m) => !m.isNewMatch).toList();

          return CustomScrollView(
            slivers: [
              _sectionHeader('Tương hợp mới', newMatches.length),
              SliverToBoxAdapter(
                child: newMatches.isEmpty
                    ? _hint('Chưa có tương hợp mới. Tiếp tục quẹt nhé!')
                    : SizedBox(
                        height: 116,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: newMatches.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) =>
                              _buildNewMatch(context, newMatches[index]),
                        ),
                      ),
              ),
              _sectionHeader('Cuộc trò chuyện', conversations.length),
              if (conversations.isEmpty)
                SliverToBoxAdapter(
                  child: _hint(
                      'Chạm vào một tương hợp mới ở trên để bắt đầu trò chuyện.'),
                )
              else
                SliverList.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 84),
                  itemBuilder: (context, index) => _buildConversation(
                      context, conversations[index], myId),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildNewMatch(BuildContext context, MatchModel match) {
    final name = _displayName(match);
    return GestureDetector(
      onTap: () => _openChat(context, match),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: ChatAvatar(
                  url: match.otherProfile?.mainAvatarUrl,
                  name: name,
                  radius: 32,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name.split(' ').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(
      BuildContext context, MatchModel match, String? myId) {
    final name = _displayName(match);
    final unread = match.unreadCount;
    final hasUnread = unread > 0;
    final prefix = match.lastSenderId == myId ? 'Bạn: ' : '';
    final time = match.lastMessageTime;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ChatAvatar(
        url: match.otherProfile?.mainAvatarUrl,
        name: name,
        radius: 28,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '$prefix${match.lastMessage ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread
              ? Theme.of(context).colorScheme.onSurface
              : Colors.grey[600],
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time != null)
            Text(
              ChatTimeFormat.listTime(time),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? AppColors.primary : Colors.grey,
              ),
            ),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () => _openChat(context, match),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Bạn chưa tương hợp với ai cả.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy tiếp tục khám phá!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/discovery'),
            child: const Text('Khám phá ngay'),
          ),
        ],
      ),
    );
  }
}

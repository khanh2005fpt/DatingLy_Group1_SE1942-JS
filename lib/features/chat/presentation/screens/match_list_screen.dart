import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/match_model.dart';
import '../viewmodels/chat_view_model.dart';

class MatchListScreen extends ConsumerWidget {
  const MatchListScreen({super.key});

  Future<void> _openChat(BuildContext context, MatchModel match) async {
    final profile = match.otherProfile;
    final name = profile?.fullName;
    final avatar = profile?.mainAvatarUrl;
    final bio = profile?.bio;
    final tags = profile?.tags ?? <String>[];

    await context.push(
      '/chat/${match.id}',
      extra: {
        'otherUserName': name,
        'otherAvatarUrl': avatar,
        'otherBio': bio,
        'otherTags': tags,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);

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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 72,
                    color: Colors.grey[300],
                  ),
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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: matches.length,
            separatorBuilder: (context, separatorIndex) =>
                const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              final match = matches[index];
              final profile = match.otherProfile;
              final name = profile?.fullName.isNotEmpty == true
                  ? profile!.fullName
                  : 'Người ẩn danh';
              final avatar = profile?.mainAvatarUrl;
              final lastMsg = match.lastMessage ?? 'Hãy bắt đầu trò chuyện!';
              final unread = match.unreadCount;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                          ? NetworkImage(avatar)
                          : null,
                      child: (avatar == null || avatar.isEmpty)
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight:
                        unread > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread > 0 ? AppColors.textPrimary : Colors.grey[600],
                    fontWeight:
                        unread > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: unread > 0
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: () => _openChat(context, match),
              );
            },
          );
        },
      ),
    );
  }
}

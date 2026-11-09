import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_colors.dart';
import '../../../data/models/who_liked_user_item.dart';
import '../../ViewModels/discovery_view_model.dart';
import '../../ViewModels/who_liked_me_view_model.dart';
import '../Widget/app_image.dart';
import 'match_celebration_screen.dart';
import 'view_profile_screen.dart';

/// Màn "Ai đã thích bạn" (module 4): lưới người đã like mình, like lại để match.
class WhoLikedMeScreen extends ConsumerWidget {
  const WhoLikedMeScreen({super.key});

  Future<void> _likeBack(
      BuildContext context, WidgetRef ref, WhoLikedUserItem item) async {
    final matchId = await ref
        .read(whoLikedMeViewModelProvider.notifier)
        .likeBack(item.user);
    if (matchId != null && context.mounted) {
      showMatchCelebration(context, matchId: matchId, other: item.user);
    }
  }

  void _openProfile(
      BuildContext context, WidgetRef ref, WhoLikedUserItem item) {
    final vm = ref.read(whoLikedMeViewModelProvider.notifier);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profile: item.user.toMap()..['id'] = item.user.id,
          myTags: ref.read(discoveryViewModelProvider).myTags,
          isLikedMe: true,
          // Đã match thì chỉ xem, không hiện nút
          onLike: item.isMatched ? null : () => _likeBack(context, ref, item),
          onNope: item.isMatched ? null : () => vm.passUser(item.user),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whoLikedMeViewModelProvider);
    final vm = ref.read(whoLikedMeViewModelProvider.notifier);
    final blurred = !state.isGoldUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ai đã thích bạn'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: blurred ? 'Hiện ảnh' : 'Làm mờ ảnh',
            icon: Icon(
              blurred
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.primary,
            ),
            onPressed: vm.toggleGoldPreview,
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (state.isLoading && state.items.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (state.errorMessage != null && state.items.isEmpty) {
          return _EmptyView(
            icon: Icons.error_outline,
            text: state.errorMessage!,
            buttonLabel: 'Thử lại',
            onPressed: vm.loadWhoLikedMe,
          );
        }
        if (state.items.isEmpty) {
          return _EmptyView(
            icon: Icons.favorite_border,
            text: 'Chưa có ai thích bạn.\nHãy tiếp tục quẹt nhé!',
            buttonLabel: 'Khám phá ngay',
            onPressed: () => context.go('/discovery'),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: vm.loadWhoLikedMe,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${state.items.length} người',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' đã thích bạn'),
                    ]),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: state.items.length,
                  itemBuilder: (context, i) {
                    final item = state.items[i];
                    return _LikerCard(
                      item: item,
                      blurred: blurred,
                      onTap: () => _openProfile(context, ref, item),
                      onLike: () => _likeBack(context, ref, item),
                      onPass: () => vm.passUser(item.user),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _LikerCard extends StatelessWidget {
  final WhoLikedUserItem item;
  final bool blurred;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onPass;

  const _LikerCard({
    required this.item,
    required this.blurred,
    required this.onTap,
    required this.onLike,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    final name = user.fullName.isEmpty ? '?' : user.fullName;
    // Khi làm mờ chỉ lộ chữ cái đầu
    final shownName = blurred ? '${name[0]}***' : name;

    Widget photo = user.mainAvatarUrl.isEmpty
        ? Container(
            decoration:
                const BoxDecoration(gradient: AppColors.primaryGradient),
            alignment: Alignment.center,
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          )
        : Image(
            image: appImageProvider(user.mainAvatarUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: Colors.grey[300]),
          );
    if (blurred) {
      photo = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: photo,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo,
            if (item.isSuperLike)
              const Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.star_rounded,
                      color: Colors.blueAccent, size: 18),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$shownName, ${user.age}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    item.isMatched
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Đã tương hợp',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          )
                        : Row(
                            children: [
                              _RoundButton(
                                icon: Icons.close_rounded,
                                color: Colors.grey,
                                onPressed: onPass,
                              ),
                              const SizedBox(width: 8),
                              _RoundButton(
                                icon: Icons.favorite_rounded,
                                color: AppColors.primary,
                                onPressed: onLike,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundButton(
      {required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _EmptyView({
    required this.icon,
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

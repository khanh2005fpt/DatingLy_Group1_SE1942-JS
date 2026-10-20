import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/who_liked_user_item.dart';
import '../viewmodels/who_liked_me_view_model.dart';

class WhoLikedMeScreen extends ConsumerWidget {
  const WhoLikedMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whoLikedMeViewModelProvider);
    final viewModel = ref.read(whoLikedMeViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF18181C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ai đã thích bạn',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: state.isGoldUnlocked ? 'Làm mờ ảnh' : 'Mở khoá xem trước',
            icon: Icon(
              state.isGoldUnlocked
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFFFFD700),
            ),
            onPressed: viewModel.toggleGoldPreview,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: viewModel.loadWhoLikedMe,
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : Column(
              children: [
                // Gold Premium Header Banner
                _GoldHeaderBanner(
                  likedCount: state.items.length,
                  isGoldUnlocked: state.isGoldUnlocked,
                  onToggleUnlock: viewModel.toggleGoldPreview,
                ),

                // Main Blurred Grid
                Expanded(
                  child: state.items.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          color: const Color(0xFFFFD700),
                          onRefresh: viewModel.loadWhoLikedMe,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.68,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: state.items.length,
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              return _BlurredUserCard(
                                item: item,
                                isUnlocked: state.isGoldUnlocked,
                                onLikeBack: () async {
                                  final matchId =
                                      await viewModel.likeBack(item.user);
                                  if (context.mounted) {
                                    _showMatchNotification(
                                      context,
                                      item.user,
                                      matchId,
                                    );
                                  }
                                },
                                onPass: () => viewModel.passUser(item.user),
                                onTap: () => _showUserPreviewModal(
                                  context,
                                  item,
                                  state.isGoldUnlocked,
                                  viewModel,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  void _showMatchNotification(
    BuildContext context,
    UserModel user,
    String? matchId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1B3D), Color(0xFF1E142B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉 TƯƠNG HỢP NGAY! 🎉',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 48,
                backgroundImage: user.mainAvatarUrl.isNotEmpty
                    ? NetworkImage(user.mainAvatarUrl)
                    : null,
                child: user.mainAvatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Bạn và ${user.fullName} đã thích nhau!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hai bạn có thể trò chuyện và tìm hiểu nhau ngay bây giờ.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tiếp tục xem'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (matchId != null) {
                          context.push(
                            '/chat/$matchId',
                            extra: {
                              'otherUserName': user.fullName,
                              'otherAvatarUrl': user.mainAvatarUrl,
                              'otherBio': user.bio,
                              'otherTags': user.tags,
                            },
                          );
                        } else {
                          context.push('/matches');
                        }
                      },
                      child: const Text(
                        'Nhắn tin',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserPreviewModal(
    BuildContext context,
    WhoLikedUserItem item,
    bool isUnlocked,
    WhoLikedMeViewModel viewModel,
  ) {
    final user = item.user;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222228),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: (user.mainAvatarUrl.isNotEmpty && isUnlocked)
                      ? NetworkImage(user.mainAvatarUrl)
                      : null,
                  backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  child: (!isUnlocked)
                      ? const Icon(Icons.lock, color: Color(0xFFFFD700), size: 30)
                      : (user.mainAvatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 30)
                          : null),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUnlocked
                            ? '${user.fullName}, ${user.age}'
                            : '${user.fullName.isNotEmpty ? user.fullName[0] : '*'}***, ${user.age}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.gender,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFFFD700),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.isMatched
                                ? 'Hai bạn đã tương hợp'
                                : 'Đã thích bạn gần đây',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (user.bio.isNotEmpty) ...[
              const Text(
                'Giới thiệu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user.bio,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
            if (user.tags.isNotEmpty) ...[
              const Text(
                'Sở thích',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.tags
                    .map(
                      (tag) => Chip(
                        backgroundColor: Colors.white10,
                        side: BorderSide.none,
                        label: Text(
                          tag,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (!item.isMatched)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      label: const Text('Bỏ qua'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        viewModel.passUser(user);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.favorite, color: Colors.white),
                      label: const Text('Thích lại ngay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final matchId = await viewModel.likeBack(user);
                        if (context.mounted) {
                          _showMatchNotification(context, user, matchId);
                        }
                      },
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble, color: Colors.white),
                  label: const Text('Đến đoạn chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/matches');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.2),
                    const Color(0xFFFFA000).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: const Icon(
                Icons.star_border_rounded,
                size: 54,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có ai thích bạn gần đây',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy tiếp tục hoạt động, làm nổi bật ảnh và quẹt thẻ để thu hút thêm người thích!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.local_fire_department, color: Colors.white),
              label: const Text(
                'Khám phá ngay',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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

class _GoldHeaderBanner extends StatelessWidget {
  final int likedCount;
  final bool isGoldUnlocked;
  final VoidCallback onToggleUnlock;

  const _GoldHeaderBanner({
    required this.likedCount,
    required this.isGoldUnlocked,
    required this.onToggleUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E2723), Color(0xFF261D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.black87,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$likedCount người',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      ' đã thích bạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isUnlockedLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onToggleUnlock,
            child: Text(
              isGoldUnlocked ? 'Làm mờ' : 'Xem ảnh',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get isUnlockedLabel => isGoldUnlocked
      ? 'Chế độ xem trước ảnh mở khóa đang bật'
      : 'Bấm "Xem ảnh" để mở khoá hiệu ứng làm mờ';
}

class _BlurredUserCard extends StatelessWidget {
  final WhoLikedUserItem item;
  final bool isUnlocked;
  final VoidCallback onLikeBack;
  final VoidCallback onPass;
  final VoidCallback onTap;

  const _BlurredUserCard({
    required this.item,
    required this.isUnlocked,
    required this.onLikeBack,
    required this.onPass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    final avatar = user.mainAvatarUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: item.isMatched
                ? AppColors.primary
                : (item.isSuperLike
                    ? const Color(0xFF03A9F4)
                    : const Color(0xFFFFD700).withValues(alpha: 0.5)),
            width: item.isSuperLike ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Ảnh Profile với bộ lọc làm mờ ImageFiltered
            if (avatar.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: isUnlocked ? 0 : 16,
                  sigmaY: isUnlocked ? 0 : 16,
                ),
                child: Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackBackground(),
                ),
              )
            else
              _buildFallbackBackground(),

            // 2. Lớp phủ Gradient mờ ảo
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // 3. Huy hiệu Tinder Gold / Super Like / Matched
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isMatched
                      ? AppColors.primary
                      : (item.isSuperLike
                          ? const Color(0xFF03A9F4)
                          : const Color(0xFFFFD700)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isMatched
                          ? Icons.favorite
                          : (item.isSuperLike ? Icons.star_rounded : Icons.star),
                      size: 12,
                      color: (item.isMatched || item.isSuperLike)
                          ? Colors.white
                          : Colors.black87,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.isMatched
                          ? 'MATCHED'
                          : (item.isSuperLike ? 'SUPER LIKE' : 'LIKED'),
                      style: TextStyle(
                        color: (item.isMatched || item.isSuperLike)
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Khóa bảo mật nếu chưa mở
            if (!isUnlocked)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFFFD700),
                    size: 26,
                  ),
                ),
              ),

            // 5. Thông tin & Nút tương tác nhanh ở chân thẻ
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isUnlocked
                        ? '${user.fullName}, ${user.age}'
                        : '${user.fullName.isNotEmpty ? user.fullName[0] : '*'}***, ${user.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (!item.isMatched)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Nút Bỏ qua
                        InkWell(
                          onTap: onPass,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        // Nút Thích lại ngay để Match
                        InkWell(
                          onTap: onLikeBack,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Đã tương hợp 🎉',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
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
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      color: const Color(0xFF2B2533),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white24, size: 54),
      ),
    );
  }
}

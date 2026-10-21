import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_branding.dart';
import '../../../../data/models/user_model.dart';
import '../viewmodels/discovery_view_model.dart';
import 'who_liked_you_screen.dart';
import '../../../profile/presentation/screens/view_profile_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final AppinioSwiperController _controller = AppinioSwiperController();

  /// Số thẻ đã quẹt (= index thẻ trên cùng trong `state.cards`).
  int _consumed = 0;

  /// Nhãn LIKE / NOPE / SUPER LIKE hiện ngắn khi thẻ bay đi.
  SwipeAction? _stamp;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SwipeAction? _actionFor(AxisDirection d) => switch (d) {
        AxisDirection.right => SwipeAction.like,
        AxisDirection.left => SwipeAction.nope,
        AxisDirection.up => SwipeAction.superLike,
        AxisDirection.down => null,
      };

  void _onSwipeBegin(int previousIndex, int targetIndex, SwiperActivity a) {
    if (a is! Swipe) return;
    final action = _actionFor(a.direction);
    if (action == null) return;
    setState(() => _stamp = action);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _stamp = null);
    });
  }

  Future<void> _onSwipeEnd(
    int previousIndex,
    int targetIndex,
    SwiperActivity activity,
  ) async {
    if (activity is! Swipe) return;
    final action = _actionFor(activity.direction);
    if (action == null) return;

    final cards = ref.read(discoveryViewModelProvider).cards;
    if (previousIndex >= cards.length) return;
    final user = cards[previousIndex];

    setState(() => _consumed = targetIndex);
    final vm = ref.read(discoveryViewModelProvider.notifier);
    vm.onCardConsumed(cards.length - targetIndex);

    try {
      final matchId = await vm.recordSwipe(user.id, action);
      if (matchId != null && mounted) _showMatchDialog(user, matchId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi ghi nhận swipe: $e')));
      }
    }
  }

  void _openFilter() => context.push('/discovery/filter');

  void _openProfile(UserModel user) {
    final vm = ref.read(discoveryViewModelProvider.notifier);
    final state = ref.read(discoveryViewModelProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profile: user.toMap()..['id'] = user.id,
          distanceKm: vm.distanceTo(user),
          myTags: state.myTags,
          onLike: () => _controller.swipeRight(),
          onNope: () => _controller.swipeLeft(),
          onSuperLike: () => _controller.swipeUp(),
        ),
      ),
    );
  }

  void _showMatchDialog(UserModel user, String matchId) {
    final avatarUrl = user.mainAvatarUrl.isEmpty ? null : user.mainAvatarUrl;
    final name = user.fullName.isEmpty ? 'người ấy' : user.fullName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: const Text(
                  '🎉 It\'s a Match!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (avatarUrl != null)
                CircleAvatar(
                  radius: 45,
                  backgroundImage: NetworkImage(avatarUrl),
                )
              else
                const CircleAvatar(
                  radius: 45,
                  child: Icon(Icons.person, size: 45),
                ),
              const SizedBox(height: 12),
              Text(
                'Bạn và $name cùng thích nhau!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Xếp dọc, full chiều rộng để chữ không bị bẻ dòng
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text(
                    'Nhắn tin ngay',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    context.push(
                      '/chat/$matchId',
                      extra: {
                        'otherUserName': name,
                        'otherAvatarUrl': avatarUrl,
                        'otherBio': user.bio,
                        'otherTags': user.tags,
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Tiếp tục quẹt',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        title: const BrandWordmark(
          showSlogan: true,
          center: true,
          titleSize: 24,
          sloganSize: 10.5,
          maxSloganLines: 1,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.person_outline, color: Colors.grey),
          onPressed: () => context.push('/profile'),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final likes = ref.watch(whoLikedMeProvider).value?.length ?? 0;
              return Badge(
                isLabelVisible: likes > 0,
                label: Text(likes > 9 ? '9+' : '$likes'),
                child: IconButton(
                  tooltip: 'Ai đã thích bạn',
                  icon: const Icon(Icons.favorite_border, color: Colors.grey),
                  onPressed: () async {
                    await context.push('/likes');
                    ref.invalidate(whoLikedMeProvider);
                  },
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Bộ lọc',
            icon: const Icon(Icons.tune_rounded, color: Colors.grey),
            onPressed: _openFilter,
          ),
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(matchCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey,
                    ),
                    onPressed: () => context.go('/matches'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(discoveryViewModelProvider);

    if (state.isLoading) {
      // Reset vị trí khi tải lại (đổi filter / refresh)
      _consumed = 0;
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.errorMessage != null && state.cards.isEmpty) {
      return _messageView(
        icon: Icons.error_outline,
        text: state.errorMessage!,
        primaryLabel: 'Thử lại',
        onPrimary: () =>
            ref.read(discoveryViewModelProvider.notifier).reload(),
      );
    }

    final exhausted = _consumed >= state.cards.length;
    if (exhausted) {
      if (state.hasMore || state.isLoadingMore) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      return _messageView(
        icon: Icons.people_outline,
        text: 'Bạn đã xem hết người phù hợp.\nThử nới rộng bộ lọc nhé!',
        primaryLabel: 'Chỉnh bộ lọc',
        onPrimary: _openFilter,
        secondaryLabel: 'Tải lại',
        onSecondary: () =>
            ref.read(discoveryViewModelProvider.notifier).reload(),
      );
    }

    final vm = ref.read(discoveryViewModelProvider.notifier);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                AppinioSwiper(
                  controller: _controller,
                  cardCount: state.cards.length,
                  initialIndex: _consumed,
                  maxAngle: 15,
                  threshold: 80,
                  swipeOptions: const SwipeOptions.only(
                    left: true,
                    right: true,
                    up: true,
                  ),
                  onSwipeBegin: _onSwipeBegin,
                  onSwipeEnd: _onSwipeEnd,
                  cardBuilder: (context, index) {
                    final user = state.cards[index];
                    return _SwipeCard(
                      user: user,
                      distanceKm: vm.distanceTo(user),
                      commonTags: user.tags
                          .where(state.myTags.contains)
                          .toList(),
                      onOpenProfile: () => _openProfile(user),
                    );
                  },
                ),
                if (_stamp != null) _StampOverlay(action: _stamp!),
              ],
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _messageView({
    required IconData icon,
    required String text,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onPrimary, child: Text(primaryLabel)),
            if (secondaryLabel != null)
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
            icon: Icons.close_rounded,
            color: Colors.redAccent,
            label: 'Bỏ qua',
            onPressed: () => _controller.swipeLeft(),
          ),
          _actionButton(
            icon: Icons.star_rounded,
            color: Colors.blueAccent,
            label: 'Super Like',
            onPressed: () => _controller.swipeUp(),
          ),
          _actionButton(
            icon: Icons.favorite_rounded,
            color: Colors.greenAccent[700]!,
            label: 'Thích',
            large: true,
            onPressed: () => _controller.swipeRight(),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
    bool large = false,
  }) {
    final size = large ? 36.0 : 28.0;
    final radius = large ? 36.0 : 30.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            child: IconButton(
              icon: Icon(icon, color: color, size: size),
              onPressed: onPressed,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Nhãn LIKE / NOPE / SUPER LIKE hiện khi thẻ bay đi.
class _StampOverlay extends StatelessWidget {
  final SwipeAction action;
  const _StampOverlay({required this.action});

  @override
  Widget build(BuildContext context) {
    final (text, color, angle) = switch (action) {
      SwipeAction.like => ('LIKE', Colors.greenAccent[700]!, -0.2),
      SwipeAction.nope => ('NOPE', Colors.redAccent, 0.2),
      SwipeAction.superLike => ('SUPER LIKE', Colors.blueAccent, 0.0),
    };
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.6),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.85),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeCard extends StatefulWidget {
  final UserModel user;
  final double? distanceKm;
  final List<String> commonTags;
  final VoidCallback onOpenProfile;

  const _SwipeCard({
    required this.user,
    required this.distanceKm,
    required this.commonTags,
    required this.onOpenProfile,
  });

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photoUrls = user.avatarUrls;
    final name = user.fullName.isEmpty ? 'Ẩn danh' : user.fullName;
    final distance = widget.distanceKm;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.25),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photoUrls.isNotEmpty
                ? Image.network(
                    photoUrls[_currentImageIndex],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person,
                          size: 100, color: Colors.white),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 80,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

            // Tap nửa trái / phải để đổi ảnh (chừa phần thông tin ở dưới)
            if (photoUrls.length > 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 150,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentImageIndex > 0) {
                            setState(() => _currentImageIndex--);
                          }
                        },
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentImageIndex < photoUrls.length - 1) {
                            setState(() => _currentImageIndex++);
                          }
                        },
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                  ],
                ),
              ),

            if (photoUrls.length > 1)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    photoUrls.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentImageIndex == i ? 24 : 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

            // Thông tin (nhấn để mở hồ sơ chi tiết)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.onOpenProfile,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$name, ${user.age}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.info_outline,
                              color: Colors.white70, size: 22),
                        ],
                      ),
                      if (distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                distance < 1
                                    ? 'Dưới 1 km'
                                    : '${distance.round()} km',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      if (widget.commonTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.commonTags
                              .take(3)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(t,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

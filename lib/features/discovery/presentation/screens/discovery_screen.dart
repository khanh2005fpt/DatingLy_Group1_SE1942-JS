import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_branding.dart';
import '../../../../data/models/user_model.dart';
import '../viewmodels/discovery_view_model.dart';
import '../../../profile/presentation/viewmodels/preferences_view_model.dart';
import '../../../profile/presentation/screens/view_profile_screen.dart';
import '../../../chat/presentation/screens/match_celebration_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  final List<Map<String, String>> _tabs = [
    {'label': '♀ Nữ', 'gender': 'Nữ'},
    {'label': '♂ Nam', 'gender': 'Nam'},
    {'label': '⚧ Khác', 'gender': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    // Khôi phục tab giới tính đã chọn lần trước từ SharedPreferences
    final saved = ref.read(preferencesViewModelProvider).genderFilter;
    final initial = _tabs.indexWhere((t) => t['gender'] == saved);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initial < 0 ? 0 : initial,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref
            .read(preferencesViewModelProvider.notifier)
            .setGenderFilter(_tabs[_tabController.index]['gender']);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map(
              (t) => _GenderSwipeTab(gender: t['gender']!),
            )
            .toList(),
      ),
    );
  }
}

/// Widget riêng cho từng tab giới tính — mỗi tab có stack thẻ riêng
class _GenderSwipeTab extends ConsumerStatefulWidget {
  final String gender;

  const _GenderSwipeTab({required this.gender});

  @override
  ConsumerState<_GenderSwipeTab> createState() => _GenderSwipeTabState();
}

class _GenderSwipeTabState extends ConsumerState<_GenderSwipeTab>
    with AutomaticKeepAliveClientMixin {
  final AppinioSwiperController _controller = AppinioSwiperController();
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Giữ state khi chuyển tab

  @override
  void initState() {
    super.initState();
    // Riverpod không cho đổi provider trong initState -> hoãn sau khi dựng xong
    Future.microtask(_loadProfiles);
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final provider = discoveryViewModelProvider(widget.gender);

    try {
      await ref.read(provider.notifier).loadCandidates();
    } catch (e) {
      debugPrint('Discovery load error: $e');
    }
    if (!mounted) return;

    final result = ref.read(provider);
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
    }
    setState(() {
      _profiles = result.candidates
          .map((UserModel u) => u.toMap())
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _onSwipeEnd(
    int previousIndex,
    int targetIndex,
    SwiperActivity activity,
  ) async {
    if (activity is Swipe) {
      final isLike = activity.direction == AxisDirection.right;
      final swipedProfile = _profiles[previousIndex];
      final swipedId = swipedProfile['id'];

      try {
        final matchId = await ref
            .read(discoveryViewModelProvider(widget.gender).notifier)
            .recordSwipe(swipedId, isLike);

        if (matchId != null && mounted) {
          showMatchCelebration(
            context,
            matchId: matchId,
            other: UserModel.fromMap(swipedProfile, swipedId),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi khi ghi nhận swipe: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có hồ sơ ${widget.gender} nào.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: AppinioSwiper(
              controller: _controller,
              cardCount: _profiles.length,
              onSwipeEnd: _onSwipeEnd,
              cardBuilder: (context, index) => _buildCard(_profiles[index]),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> profile) {
    return _ProfileSwipeCard(
      profile: profile,
      onOpenProfile: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewProfileScreen(
              profile: profile,
              onLike: () => _controller.swipeRight(),
              onNope: () => _controller.swipeLeft(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.close_rounded,
            color: Colors.redAccent,
            onPressed: () => _controller.swipeLeft(),
            label: 'Bỏ qua',
          ),
          _buildActionButton(
            icon: Icons.favorite_rounded,
            color: Colors.greenAccent[700]!,
            onPressed: () => _controller.swipeRight(),
            label: 'Thích',
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
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

class _ProfileSwipeCard extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onOpenProfile;

  const _ProfileSwipeCard({required this.profile, required this.onOpenProfile});

  @override
  State<_ProfileSwipeCard> createState() => _ProfileSwipeCardState();
}

class _ProfileSwipeCardState extends State<_ProfileSwipeCard> {
  int _currentImageIndex = 0;

  void _nextImage(int maxImages) {
    if (_currentImageIndex < maxImages - 1) {
      setState(() => _currentImageIndex++);
    }
  }

  void _prevImage() {
    if (_currentImageIndex > 0) {
      setState(() => _currentImageIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final List<String> photoUrls = profile['avatar_urls'] != null
        ? List<String>.from(profile['avatar_urls'])
        : [];

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
            // Ảnh đại diện
            photoUrls.isNotEmpty
                ? Image.network(
                    photoUrls[_currentImageIndex],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Center(
                      child: Text(
                        (profile['full_name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 80,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

            // Tap detector nửa trái / nửa phải để đổi ảnh (chỉ lấy 70% chiều cao trên cùng)
            if (photoUrls.length > 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 150, // Tránh đè lên phần thông tin ở dưới
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _prevImage,
                        behavior: HitTestBehavior.translucent,
                        child: Container(),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _nextImage(photoUrls.length),
                        behavior: HitTestBehavior.translucent,
                        child: Container(),
                      ),
                    ),
                  ],
                ),
              ),

            // Indicator dots ở trên cùng
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
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Gradient overlay & Info (nhấn vào đây mở profile)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.onOpenProfile,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${profile['full_name'] ?? 'Ẩn danh'}, ${profile['age'] ?? '?'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Info icon
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      if (profile['bio'] != null &&
                          (profile['bio'] as String).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          profile['bio'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (profile['tags'] != null &&
                          (profile['tags'] as List).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: (profile['tags'] as List)
                              .take(3)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white30,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tag.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
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

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Màn hình xem profile của người khác (hiện ra khi ấn vào thẻ quẹt)
class ViewProfileScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isLikedMe;
  final VoidCallback? onLike;
  final VoidCallback? onNope;
  final VoidCallback? onSuperLike;

  const ViewProfileScreen({
    super.key,
    required this.profile,
    this.isLikedMe = false,
    this.onLike,
    this.onNope,
    this.onSuperLike,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrls = profile['avatar_urls'];
    final List<String> photoUrls = avatarUrls != null
        ? List<String>.from(avatarUrls)
        : [];
    final String name = profile['full_name'] ?? 'Ẩn danh';
    final int? age = profile['age'];
    final String? gender = profile['gender'];
    final String? bio = profile['bio'];
    final List<dynamic> tags = profile['tags'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── SliverAppBar với ảnh ───
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ảnh đại diện (slide gallery nếu có nhiều)
                  if (photoUrls.isNotEmpty)
                    _PhotoGallery(photoUrls: photoUrls)
                  else
                    _buildPlaceholder(name),

                  // Gradient overlay
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),

                  // Tên + tuổi + Huy hiệu Đã thích bạn
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLikedMe)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Đã thích bạn',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          age != null ? '$name, $age' : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black45)
                            ],
                          ),
                        ),
                        if (gender != null)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(gender,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Nội dung ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio
                  if (bio != null && bio.isNotEmpty) ...[
                    _sectionTitle('Về ${name.split(' ').first}'),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tags
                  if (tags.isNotEmpty) ...[
                    _sectionTitle('Sở thích'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Nút Like / Nope / Super Like
                  if (onLike != null || onNope != null || onSuperLike != null) ...[
                    Row(
                      children: [
                        if (onNope != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.redAccent),
                              label: const Text('Bỏ qua',
                                  style:
                                      TextStyle(color: Colors.redAccent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.redAccent),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                onNope?.call();
                              },
                            ),
                          ),
                        if (onSuperLike != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF03A9F4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              onSuperLike?.call();
                            },
                            child: const Icon(Icons.star_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 8),
                        ] else if (onNope != null && onLike != null)
                          const SizedBox(width: 12),
                        if (onLike != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.favorite_rounded),
                              label: const Text('Thích'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                onLike?.call();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              fontSize: 100,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary));
  }
}

/// Gallery ảnh có thể vuốt ngang
class _PhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  const _PhotoGallery({required this.photoUrls});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.photoUrls.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.photoUrls.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) => Image.network(
            widget.photoUrls[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.person, size: 80, color: Colors.white),
            ),
          ),
        ),
        // Tap detector (trái/phải) để đổi ảnh
        if (widget.photoUrls.length > 1)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _prevPage,
                    behavior: HitTestBehavior.translucent,
                    child: Container(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _nextPage,
                    behavior: HitTestBehavior.translucent,
                    child: Container(),
                  ),
                ),
              ],
            ),
          ),
        // Dots indicator
        if (widget.photoUrls.length > 1)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photoUrls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/app_providers.dart';
import '../../app_colors.dart';
import '../Widget/app_branding_widget.dart';

class _WelcomeSlide {
  final IconData icon;
  final String title;
  final String description;

  const _WelcomeSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Màn chào hiển thị một lần khi mở app lần đầu (điều khiển bởi cờ isFirstTimeUser).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _slides = [
    _WelcomeSlide(
      icon: Icons.explore_rounded,
      title: 'Khám phá người phù hợp',
      description:
          'Lướt qua hồ sơ gần bạn, lọc theo độ tuổi, khoảng cách và sở thích chung.',
    ),
    _WelcomeSlide(
      icon: Icons.favorite_rounded,
      title: 'Kết nối khi cùng thích nhau',
      description:
          'Khi hai bên cùng quẹt phải, bạn sẽ có một match và bắt đầu trò chuyện.',
    ),
    _WelcomeSlide(
      icon: Icons.chat_bubble_rounded,
      title: 'Trò chuyện & làm quen',
      description:
          'Nhắn tin, chơi mini game và để AI gợi ý cách bắt chuyện tự nhiên hơn.',
    ),
  ];

  final _pageController = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingRepositoryProvider).setIsFirstTimeUser(false);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppBrandingWidget(compact: true),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(slide.icon, size: 64, color: Colors.white),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active ? AppColors.primary : Colors.grey[300],
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _next,
                    child: Text(
                      _isLast ? 'Bắt đầu 🚀' : 'Tiếp tục',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_colors.dart';
import '../Widget/app_image.dart';
import '../../../data/models/user_model.dart';
import '../../ViewModels/profile_view_model.dart';

/// Hàm hiển thị popup chúc mừng tương hợp rực rỡ khi 2 người cùng thích nhau.
///
/// Tham số:
/// - [context]: BuildContext hiện tại
/// - [matchId]: ID của match vừa tạo giữa 2 người (để chuyển hướng sang chat)
/// - [other]: Đối tượng UserModel của người bên kia (chứa tên, avatar, bio, tags...)
/// - [myAvatarUrl] & [myName]: (Tùy chọn) Thông tin hồ sơ của bạn nếu đã có sẵn
Future<void> showMatchCelebration(
  BuildContext context, {
  required String matchId,
  required UserModel other,
  String? myAvatarUrl,
  String? myName,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'match',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) =>
        MatchCelebrationScreen(
      matchId: matchId,
      other: other,
      myAvatarUrl: myAvatarUrl,
      myName: myName,
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class MatchCelebrationScreen extends ConsumerStatefulWidget {
  final String matchId;
  final UserModel other;
  final String? myAvatarUrl;
  final String? myName;

  const MatchCelebrationScreen({
    super.key,
    required this.matchId,
    required this.other,
    this.myAvatarUrl,
    this.myName,
  });

  @override
  ConsumerState<MatchCelebrationScreen> createState() =>
      _MatchCelebrationScreenState();
}

class _MatchCelebrationScreenState extends ConsumerState<MatchCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Vị trí / kích thước ngẫu nhiên của các trái tim bay nền
  final List<({double x, double offset, double size})> _hearts = List.generate(
    16,
    (i) {
      final rnd = math.Random(i * 7 + 3);
      return (
        x: rnd.nextDouble(),
        offset: rnd.nextDouble(),
        size: 14 + rnd.nextDouble() * 22,
      );
    },
  );

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _float.dispose();
    super.dispose();
  }

  /// Tính tỉ lệ 0..1 của [_enter] trong khoảng [begin, end]
  double _phase(double begin, double end, [Curve curve = Curves.easeOut]) {
    final t = ((_enter.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  void _openChat() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      '/chat/${widget.matchId}',
      extra: {
        'otherUserName': widget.other.fullName,
        'otherAvatarUrl': widget.other.mainAvatarUrl,
        'otherBio': widget.other.bio,
        'otherTags': widget.other.tags,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileStreamProvider).value;
    final myAvatar = widget.myAvatarUrl ?? me?.mainAvatarUrl;
    final myFullName = widget.myName ?? me?.fullName ?? 'Bạn';
    final otherName =
        widget.other.fullName.isNotEmpty ? widget.other.fullName : 'người ấy';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.94),
              AppColors.primaryDark.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildFloatingHearts()),
            SafeArea(
              child: AnimatedBuilder(
                animation: _enter,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Transform.scale(
                        scale: _phase(0, 0.45, Curves.elasticOut),
                        child: const Text(
                          "It's a Match!",
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 14, color: Colors.black38),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _phase(0.2, 0.5),
                        child: Text(
                          'Bạn và $otherName đã thích nhau 💕',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildAvatars(myAvatar, myFullName),
                      const Spacer(flex: 3),
                      Opacity(
                        opacity: _phase(0.6, 1),
                        child: _buildButtons(),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildAvatars(String? myAvatar, String myName) {
    final slide = _phase(0.15, 0.6, Curves.easeOutBack);
    final heartScale = _phase(0.5, 0.85, Curves.elasticOut);

    return SizedBox(
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-62 - (1 - slide) * 260, 0),
            child: Transform.rotate(
              angle: -0.12,
              child: _avatar(myAvatar, myName),
            ),
          ),
          Transform.translate(
            offset: Offset(62 + (1 - slide) * 260, 0),
            child: Transform.rotate(
              angle: 0.12,
              child: _avatar(widget.other.mainAvatarUrl, widget.other.fullName),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 62),
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.15).animate(_pulse),
              child: Transform.scale(
                scale: heartScale,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(blurRadius: 14, color: Colors.black26),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? url, String name) {
    final hasUrl = url != null && url.isNotEmpty;
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26)],
        color: Colors.white,
        image: hasUrl
            ? DecorationImage(image: appImageProvider(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasUrl
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              elevation: 4,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('Nhắn tin ngay'),
            onPressed: _openChat,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.8),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tiếp tục quẹt'),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingHearts() {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _float,
        builder: (context, _) => Stack(
          children: _hearts.map((h) {
            final t = (_float.value + h.offset) % 1.0;
            return Positioned(
              left: h.x * constraints.maxWidth,
              top: constraints.maxHeight * (1 - t) - h.size,
              child: Opacity(
                opacity: (math.sin(t * math.pi) * 0.6).clamp(0.0, 1.0),
                child: Icon(Icons.favorite, color: Colors.white, size: h.size),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}


import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../profile/presentation/screens/view_profile_screen.dart';
import '../viewmodels/discovery_view_model.dart';

/// Đặt true để làm mờ ảnh kiểu "Tinder Gold".
const bool kBlurLikedYou = false;

/// Danh sách người đã thích mình mà mình chưa quẹt lại.
final whoLikedMeProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final myId = ref.watch(firebaseAuthServiceProvider).currentUser?.uid;
  if (myId == null) return [];
  return ref.read(firestoreServiceProvider).getUsersWhoLikedMe(myId);
});

class WhoLikedYouScreen extends ConsumerWidget {
  const WhoLikedYouScreen({super.key});

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    SwipeAction action,
  ) async {
    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (myId == null) return;
    try {
      final matchId = await ref.read(firestoreServiceProvider).recordSwipe(
            myId: myId,
            targetUserId: user.id,
            action: action.value,
          );
      ref.invalidate(whoLikedMeProvider);
      if (!context.mounted) return;
      if (matchId != null) {
        context.push('/chat/$matchId', extra: {
          'otherUserName': user.fullName,
          'otherAvatarUrl':
              user.mainAvatarUrl.isEmpty ? null : user.mainAvatarUrl,
          'otherBio': user.bio,
          'otherTags': user.tags,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _open(BuildContext context, WidgetRef ref, UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profile: user.toMap()..['id'] = user.id,
          myTags: ref.read(discoveryViewModelProvider).myTags,
          onLike: () => _respond(context, ref, user, SwipeAction.like),
          onNope: () => _respond(context, ref, user, SwipeAction.nope),
          onSuperLike: () =>
              _respond(context, ref, user, SwipeAction.superLike),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(whoLikedMeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ai đã thích bạn')),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lỗi tải danh sách: $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(whoLikedMeProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Text('Chưa có ai thích bạn.\nHãy tiếp tục quẹt nhé!',
                  textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(whoLikedMeProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: users.length,
              itemBuilder: (context, i) => _LikerTile(
                user: users[i],
                onTap: () => _open(context, ref, users[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _LikerTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photo = user.mainAvatarUrl;
    Widget image = photo.isEmpty
        ? Container(
            decoration:
                const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Center(
              child: Text(
                user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 56,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          )
        : Image.network(photo, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: Colors.grey[300]));

    if (kBlurLikedYou) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: image,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Text(
                  kBlurLikedYou ? '${user.age} tuổi' : '${user.fullName}, ${user.age}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.favorite, color: AppColors.primary, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

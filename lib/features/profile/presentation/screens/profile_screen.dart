import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/profile_view_model.dart';
import '../viewmodels/preferences_view_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authViewModelProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileStreamProvider);
    final prefsState = ref.watch(preferencesViewModelProvider);

    return Scaffold(
      body: profileAsync.when(
        data: (profile) => _buildContent(profile, prefsState),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }

  Widget _buildContent(UserModel? profile, PreferencesState prefsState) {
    final List<String> photoUrls = profile?.avatarUrls ?? [];
    final String name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Ẩn danh';
    final int age = profile?.age ?? 18;
    final String gender = profile?.gender ?? 'Khác';
    final String bio = profile?.bio ?? 'Chưa có tiểu sử.';
    final List<String> tags = profile?.tags ?? [];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          stretch: true,
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Cài đặt',
              onPressed: () => context.push('/settings'),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Chỉnh sửa hồ sơ',
              onPressed: () {
                context.push('/profile/edit', extra: profile?.toMap());
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                photoUrls.isNotEmpty
                    ? _PhotoGallery(photoUrls: photoUrls)
                    : _buildAvatarPlaceholder(name),
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.0, 0.5],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$name, $age',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 4,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              gender,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Giới thiệu bản thân'),
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (tags.isNotEmpty) ...[
                  _sectionTitle('Sở thích'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                ],

                // ─── CẤU HÌNH & TRẠNG THÁI (SharedPreferences) ───
                _sectionTitle('Cài đặt & Cấu hình (SharedPreferences)'),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined,
                            color: AppColors.primary),
                        title: const Text('Chế độ tối (Dark Mode)'),
                        subtitle: const Text('Lưu trạng thái vào SharedPreferences'),
                        value: prefsState.isDarkMode,
                        onChanged: (_) {
                          ref
                              .read(preferencesViewModelProvider.notifier)
                              .toggleDarkMode();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_outlined,
                            color: AppColors.primary),
                        title: const Text('Thông báo Firebase (FCM)'),
                        subtitle: const Text('Bật/tắt thông báo đẩy'),
                        value: prefsState.notificationsEnabled,
                        onChanged: (_) {
                          ref
                              .read(preferencesViewModelProvider.notifier)
                              .toggleNotifications();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Chỉnh sửa hồ sơ'),
                    onPressed: () {
                      context.push('/profile/edit', extra: profile?.toMap());
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout,
                        size: 18, color: Colors.redAccent),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _signOut,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  const _PhotoGallery({required this.photoUrls});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photoUrls.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            return Image.network(
              widget.photoUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image, size: 60),
              ),
            );
          },
        ),
        if (widget.photoUrls.length > 1)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              children: List.generate(
                widget.photoUrls.length,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

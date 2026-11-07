import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/viewmodels/preferences_view_model.dart';
import '../viewmodels/settings_view_model.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  // ─── Dialogs ──────────────────────────────────────────────────────────────

  Future<void> _showChangeEmailDialog() async {
    final currentPassCtrl = TextEditingController();
    final newEmailCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Đổi Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Mật khẩu hiện tại',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email mới',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (currentPassCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập mật khẩu hiện tại')),
                  );
                  return;
                }
                if (!newEmailCtrl.text.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập địa chỉ email hợp lệ')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(settingsViewModelProvider.notifier).updateEmail(
              currentPassword: currentPassCtrl.text,
              newEmail: newEmailCtrl.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                'Email xác nhận đã được gửi tới địa chỉ mới. Vui lòng kiểm tra hộp thư.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().contains('wrong-password') ||
                  e.toString().contains('invalid-credential')
              ? 'Mật khẩu hiện tại không chính xác'
              : 'Lỗi đổi email: $e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text(errorMsg)),
          );
        }
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Đổi Mật khẩu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu hiện tại',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu mới (ít nhất 6 ký tự)',
                    prefixIcon: const Icon(Icons.lock_reset),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureNew,
                  decoration: const InputDecoration(
                    hintText: 'Xác nhận mật khẩu mới',
                    prefixIcon: Icon(Icons.check_circle_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (currentPassCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập mật khẩu hiện tại'),
                    ),
                  );
                  return;
                }
                if (newPassCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu mới phải từ 6 ký tự trở lên'),
                    ),
                  );
                  return;
                }
                if (newPassCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu xác nhận không khớp'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(settingsViewModelProvider.notifier).updatePassword(
              currentPassword: currentPassCtrl.text,
              newPassword: newPassCtrl.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('Mật khẩu đã được cập nhật thành công!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().contains('wrong-password') ||
                  e.toString().contains('invalid-credential')
              ? 'Mật khẩu hiện tại không chính xác'
              : 'Lỗi đổi mật khẩu: $e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text(errorMsg)),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc muốn đăng xuất không?\nDữ liệu cache local sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(settingsViewModelProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(preferencesViewModelProvider);
    final settingsState = ref.watch(settingsViewModelProvider);
    final currentEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Chưa có email';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Cài đặt tài khoản'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: settingsState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // ── Tài khoản ──────────────────────────────────────────────
                _SectionHeader(title: 'Tài khoản'),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Email'),
                      subtitle: Text(
                        currentEmail,
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: TextButton(
                        onPressed: _showChangeEmailDialog,
                        child: const Text(
                          'Đổi',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                      ),
                      title: const Text('Mật khẩu'),
                      subtitle: const Text(
                        '••••••••',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: TextButton(
                        onPressed: _showChangePasswordDialog,
                        child: const Text(
                          'Đổi',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Thông báo & Hiển thị ────────────────────────────────────
                _SectionHeader(title: 'Thông báo & Hiển thị'),
                _SettingsCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Thông báo đẩy (FCM)'),
                      subtitle: const Text(
                        'Nhận thông báo match và tin nhắn mới',
                      ),
                      value: prefsState.notificationsEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (_) => ref
                          .read(preferencesViewModelProvider.notifier)
                          .toggleNotifications(),
                    ),
                    const Divider(height: 1, indent: 16),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.dark_mode_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Chế độ tối'),
                      subtitle: const Text('Dark Mode'),
                      value: prefsState.isDarkMode,
                      activeThumbColor: AppColors.primary,
                      onChanged: (_) => ref
                          .read(preferencesViewModelProvider.notifier)
                          .toggleDarkMode(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Quyền riêng tư ──────────────────────────────────────────
                _SectionHeader(title: 'Quyền riêng tư'),
                _SettingsCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.visibility_off_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Chế độ ẩn danh'),
                      subtitle: const Text(
                        'Tạm ẩn hồ sơ khỏi danh sách khám phá',
                      ),
                      value: settingsState.ghostMode,
                      activeThumbColor: AppColors.primary,
                      onChanged: (_) => ref
                          .read(settingsViewModelProvider.notifier)
                          .toggleGhostMode(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── An toàn ──────────────────────────────────────────────────
                _SectionHeader(title: 'An toàn'),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Trung tâm an toàn'),
                      subtitle: const Text('Báo cáo, chặn người dùng vi phạm'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/safety'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Đăng xuất ────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
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

                // Error banner
                if (settingsState.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Lỗi: ${settingsState.error}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(children: children),
    );
  }
}

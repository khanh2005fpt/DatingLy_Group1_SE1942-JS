import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/models/user_model.dart';
import '../viewmodels/settings_view_model.dart';

class SafetyScreen extends ConsumerStatefulWidget {
  /// Nếu có sẵn userId (navigate từ profile card), form có thể pre-fill
  final String? prefilledUserId;

  const SafetyScreen({super.key, this.prefilledUserId});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Report Form state
  final _reportIdCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ReportReason _selectedReason = ReportReason.spam;
  XFile? _screenshotFile;
  bool _reportSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.prefilledUserId != null) {
      _reportIdCtrl.text = widget.prefilledUserId!;
    }
    // Load danh sách bị chặn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsViewModelProvider.notifier).loadBlockedUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportIdCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─── Chọn ảnh chụp màn hình ──────────────────────────────────────────────

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _screenshotFile = file);
  }

  // ─── Gửi báo cáo ─────────────────────────────────────────────────────────

  Future<void> _submitReport() async {
    if (_reportIdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập ID người dùng bị báo cáo')),
      );
      return;
    }

    await ref
        .read(settingsViewModelProvider.notifier)
        .submitReport(
          reportedId: _reportIdCtrl.text.trim(),
          reason: _selectedReason.label,
          description: _descCtrl.text.trim(),
          screenshotFile: _screenshotFile,
        );

    final error = ref.read(settingsViewModelProvider).error;
    if (!mounted) return;

    if (error == null) {
      setState(() {
        _reportSent = true;
        _reportIdCtrl.clear();
        _descCtrl.clear();
        _screenshotFile = null;
        _selectedReason = ReportReason.spam;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Báo cáo đã được gửi. Chúng tôi sẽ xem xét sớm.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $error'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm an toàn'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.flag_outlined), text: 'Báo cáo'),
            Tab(icon: Icon(Icons.block), text: 'Danh sách chặn'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportTab(settingsState),
          _buildBlockedTab(settingsState),
        ],
      ),
    );
  }

  // ─── Tab 1: Báo cáo ──────────────────────────────────────────────────────

  Widget _buildReportTab(SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Báo cáo vi phạm',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Giúp chúng tôi giữ cộng đồng an toàn và lành mạnh.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // User ID field
          const Text(
            'ID người dùng bị báo cáo',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reportIdCtrl,
            decoration: InputDecoration(
              hintText: 'Nhập user ID hoặc tên người dùng',
              prefixIcon: const Icon(Icons.person_search_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Reason dropdown
          const Text(
            'Lý do vi phạm',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReportReason>(
                isExpanded: true,
                value: _selectedReason,
                items: ReportReason.values
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Description
          const Text(
            'Mô tả chi tiết',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Mô tả ngắn gọn hành vi vi phạm để chúng tôi xem xét...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Screenshot
          const Text(
            'Ảnh chụp màn hình (tuỳ chọn)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _screenshotFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _screenshotFile!.path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _screenshotFile = null),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 32,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Đính kèm ảnh chụp màn hình',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 28),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(state.isLoading ? 'Đang gửi...' : 'Gửi báo cáo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: state.isLoading ? null : _submitReport,
            ),
          ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Báo cáo sẽ được xử lý trong vòng 24 giờ.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Danh sách chặn ───────────────────────────────────────────────

  Widget _buildBlockedTab(SettingsState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.blockedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa chặn ai cả',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Những người bạn đã chặn sẽ xuất hiện ở đây.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(settingsViewModelProvider.notifier).loadBlockedUsers(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: state.blockedUsers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final user = state.blockedUsers[i];
          return _BlockedUserTile(
            user: user,
            onUnblock: () async {
              await ref
                  .read(settingsViewModelProvider.notifier)
                  .unblockUser(user.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã bỏ chặn ${user.fullName}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ─── Blocked User Tile ───────────────────────────────────────────────────────

class _BlockedUserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUnblock;

  const _BlockedUserTile({required this.user, required this.onUnblock});

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: user.mainAvatarUrl.isNotEmpty
              ? NetworkImage(user.mainAvatarUrl)
              : null,
          child: user.mainAvatarUrl.isEmpty
              ? Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          user.fullName.isNotEmpty ? user.fullName : 'Người dùng ẩn',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${user.age} tuổi • ${user.gender}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: OutlinedButton(
          onPressed: onUnblock,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text(
            'Bỏ chặn',
            style: TextStyle(color: AppColors.primary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

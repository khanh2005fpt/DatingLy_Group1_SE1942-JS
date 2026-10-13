import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_branding.dart';
import '../viewmodels/auth_view_model.dart';
import '../../../profile/presentation/viewmodels/profile_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentIndex = 0;
  bool _isLoading = false;

  // ── Step 1: Thông tin cơ bản ──
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Nam';

  // ── Step 2: Bio ──
  final _bioController = TextEditingController();

  // ── Step 3: Sở thích ──
  final List<String> _selectedTags = [];
  final _customTagController = TextEditingController();
  final List<String> _availableTags = [
    'Âm nhạc',
    'Du lịch',
    'Thể thao',
    'Đọc sách',
    'Game',
    'Thú cưng',
    'Ẩm thực',
    'Phim ảnh',
    'Yoga',
    'Cà phê',
    'Nghệ thuật',
    'Thiên nhiên',
    'Nấu ăn',
    'Chụp ảnh',
    'Leo núi',
    'Bơi lội',
  ];

  // ── Step 4: Upload ảnh ──
  // Index 0 = avatar, index 1+ = profile photos
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  final List<XFile> _photoFiles = [];
  final List<Uint8List> _photoBytesL = [];

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  // ── Navigation ──
  void _next() {
    if (_currentIndex < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceed() {
    switch (_currentIndex) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _ageController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  // ── Pick avatar ──
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _avatarFile = picked;
        _avatarBytes = bytes;
      });
    }
  }

  // ── Pick profile photo ──
  Future<void> _pickPhoto() async {
    if (_photoFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 5 ảnh trang cá nhân')),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _photoFiles.add(picked);
        _photoBytesL.add(bytes);
      });
    }
  }

  // ── Add custom tag ──
  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty) return;
    if (_selectedTags.contains(tag) || _availableTags.contains(tag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sở thích này đã tồn tại')));
      return;
    }
    setState(() {
      _availableTags.add(tag);
      _selectedTags.add(tag);
      _customTagController.clear();
    });
  }

  // ── Submit ──
  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final profileVm = ref.read(profileViewModelProvider);
      final authVm = ref.read(authViewModelProvider.notifier);

      // 1. Upload ảnh trước nếu có
      final List<String> allUrls = [];

      if (_avatarFile != null) {
        try {
          final avatarUrl = await profileVm.uploadAvatar(_avatarFile!);
          allUrls.add(avatarUrl);
        } catch (_) {}
      }

      for (final photo in _photoFiles) {
        try {
          final url = await profileVm.uploadPhoto(photo);
          allUrls.add(url);
        } catch (_) {}
      }

      // 2. Lưu thông tin hồ sơ
      final success = await authVm.updateInitialProfile(
        fullName: _nameController.text.trim().isEmpty
            ? 'Ẩn danh'
            : _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 18,
        gender: _gender,
        bio: _bioController.text.trim(),
        tags: _selectedTags,
      );

      if (mounted) {
        if (success) {
          context.go('/discovery');
        } else {
          final err = ref.read(authViewModelProvider).errorMessage ?? 'Lỗi hoàn tất hồ sơ';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = ['Cơ bản', 'Tiểu sử', 'Sở thích', 'Ảnh'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const BrandBanner(compact: true),
                  const SizedBox(height: 18),
                  // Progress dots
                  Row(
                    children: List.generate(_totalSteps, (i) {
                      final isActive = i <= _currentIndex;
                      final isCurrent = i == _currentIndex;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: isCurrent ? 8 : 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isActive
                                ? AppColors.primary
                                : Colors.grey[200],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  // Step labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_totalSteps, (i) {
                      final isCurrent = i == _currentIndex;
                      return Text(
                        stepLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent ? AppColors.primary : Colors.grey,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentIndex = i),
                children: [
                  _buildBasicInfoStep(),
                  _buildBioStep(),
                  _buildTagsStep(),
                  _buildPhotosStep(),
                ],
              ),
            ),

            // ── Bottom Buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                    ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_canProceed())
                            ? null
                            : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _currentIndex < _totalSteps - 1
                                    ? 'Tiếp theo →'
                                    : '🎉 Hoàn thành',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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

  // ─────────────────────────────────────────
  // STEP 1: Thông tin cơ bản
  // ─────────────────────────────────────────
  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Thông tin cơ bản 👤',
            'Hãy cho chúng tôi biết bạn là ai',
          ),
          const SizedBox(height: 28),
          _label('Tên hiển thị'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecor('Tên của bạn', Icons.person_outline),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          _label('Tuổi'),
          const SizedBox(height: 8),
          TextField(
            controller: _ageController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            decoration: _inputDecor('Tuổi của bạn', Icons.cake_outlined),
          ),
          const SizedBox(height: 20),
          _label('Giới tính'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: _inputDecor('Giới tính', Icons.wc_outlined),
            items: [
              'Nam',
              'Nữ',
              'Khác',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _gender = v);
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STEP 2: Bio
  // ─────────────────────────────────────────
  Widget _buildBioStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Viết về bản thân ✍️',
            'Tiểu sử ấn tượng giúp bạn được chú ý hơn',
          ),
          const SizedBox(height: 28),
          _label('Tiểu sử (Bio)'),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 5,
            maxLength: 200,
            decoration: InputDecoration(
              hintText:
                  'VD: Mình thích cà phê sáng, phim kinh dị và những chuyến đi bất ngờ...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Hãy đề cập sở thích, phong cách sống hoặc điều gì đó khiến bạn độc đáo!',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STEP 3: Sở thích
  // ─────────────────────────────────────────
  Widget _buildTagsStep() {
    final customTags = _selectedTags
        .where((t) => !_availableTags.contains(t))
        .toList();
    final displayTags = [..._availableTags, ...customTags];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Sở thích của bạn 🎯',
            'Chọn những gì bạn yêu thích để tìm người phù hợp',
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedTags.length} sở thích đã chọn',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: FilterChip(
                  label: Text(
                    tag,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                  backgroundColor: Colors.white,
                  elevation: isSelected ? 0 : 0,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  }),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Custom tag input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  decoration: InputDecoration(
                    hintText: 'Thêm sở thích khác...',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.add, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                  ),
                  onSubmitted: (_) => _addCustomTag(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomTag,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Thêm'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nhập và bấm "Thêm" để tạo sở thích tùy chỉnh',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STEP 4: Upload ảnh
  // ─────────────────────────────────────────
  Widget _buildPhotosStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Ảnh của bạn 📸',
            'Thêm ảnh để tạo ấn tượng với mọi người',
          ),
          const SizedBox(height: 24),

          // ── Avatar ──
          _label('Ảnh đại diện (bắt buộc)'),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _avatarBytes != null
                            ? AppColors.primary
                            : Colors.grey[300]!,
                        width: 3,
                      ),
                      color: Colors.grey[100],
                    ),
                    child: ClipOval(
                      child: _avatarBytes != null
                          ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Chọn ảnh',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Profile Photos ──
          Row(
            children: [
              _label('Ảnh trang cá nhân'),
              const Spacer(),
              Text(
                '${_photoFiles.length}/5',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tối đa 5 ảnh — có thể bỏ qua và thêm sau',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: _photoBytesL.length + 1,
            itemBuilder: (context, index) {
              if (index == _photoBytesL.length) {
                // Nút thêm ảnh
                return GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary.withValues(alpha: 0.6),
                          size: 30,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Thêm ảnh',
                          style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              // Ảnh đã chọn
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytesL[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _photoFiles.removeAt(index);
                        _photoBytesL.removeAt(index);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Skip note
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _submit,
              child: const Text(
                'Bỏ qua ảnh, hoàn thành ngay →',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  Widget _stepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: AppColors.textPrimary,
    ),
  );

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: Colors.grey),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
  );
}

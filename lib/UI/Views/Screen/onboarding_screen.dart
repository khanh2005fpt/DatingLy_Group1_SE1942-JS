import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/profile_constants.dart';
import '../../app_colors.dart';
import '../Widget/image_crop_compress_helper.dart';
import '../Widget/app_branding_widget.dart';
import '../../ViewModels/auth_view_model.dart';
import '../../ViewModels/profile_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentIndex = 0;
  bool _isLoading = false;
  String _loadingStatus = '';

  // ── Step 1: Tên & Ngày sinh ──
  final _nameController = TextEditingController();
  DateTime? _selectedBirthDate;
  int _calculatedAge = 18;

  // ── Step 2: Giới tính & Định hướng ──
  String _gender = 'Nam';
  String _orientation = 'serious';

  // ── Step 3: Tags sở thích ──
  final List<String> _selectedTags = [];
  final _customTagController = TextEditingController();

  // ── Step 4: Ảnh Profile (Crop & Nén) ──
  final List<Uint8List> _profilePhotoBytes = [];

  static const int _totalSteps = 4;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedBirthDate = DateTime(now.year - 20, now.month, now.day);
    _calculatedAge = 20;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authViewModelProvider).userModel;
      if (user != null && user.fullName.isNotEmpty) {
        _nameController.text = user.fullName;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 16),
      helpText: 'CHỌN NGÀY SINH CỦA BẠN',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = now.year -
          picked.year -
          ((now.month < picked.month ||
                  (now.month == picked.month && now.day < picked.day))
              ? 1
              : 0);

      setState(() {
        _selectedBirthDate = picked;
        _calculatedAge = age;
      });
    }
  }

  Future<void> _pickAndProcessPhoto() async {
    if (_profilePhotoBytes.length >= 6) {
      _showToast('Bạn chỉ có thể tải lên tối đa 6 ảnh hồ sơ.');
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return;
      final rawBytes = await picked.readAsBytes();

      if (!mounted) return;

      final croppedBytes = await ImageCropCompressHelper.showCropDialog(
        context,
        imageBytes: rawBytes,
        aspectRatio: 3 / 4,
      );

      if (croppedBytes != null && mounted) {
        setState(() {
          _profilePhotoBytes.add(croppedBytes);
        });
        _showToast(
          'Đã thêm và nén ảnh thành công (${_profilePhotoBytes.length}/6)',
          isSuccess: true,
        );
      }
    } catch (e) {
      _showToast('Lỗi khi xử lý ảnh: $e');
    }
  }

  Future<void> _recropPhoto(int index) async {
    final original = _profilePhotoBytes[index];
    final recropped = await ImageCropCompressHelper.showCropDialog(
      context,
      imageBytes: original,
      aspectRatio: 3 / 4,
    );
    if (recropped != null && mounted) {
      setState(() {
        _profilePhotoBytes[index] = recropped;
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _profilePhotoBytes.removeAt(index);
    });
  }

  void _movePhoto(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _profilePhotoBytes.length) return;
    setState(() {
      final item = _profilePhotoBytes.removeAt(oldIndex);
      _profilePhotoBytes.insert(newIndex, item);
    });
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty) return;
    if (_selectedTags.contains(tag)) {
      _showToast('Sở thích này đã được chọn');
      return;
    }
    setState(() {
      _selectedTags.add(tag);
      _customTagController.clear();
    });
  }

  void _showToast(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green[700] : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _canProceed() {
    switch (_currentIndex) {
      case 0:
        return _nameController.text.trim().length >= 2 &&
            _selectedBirthDate != null &&
            _calculatedAge >= 18;
      case 1:
        return _gender.isNotEmpty && _orientation.isNotEmpty;
      case 2:
        return _selectedTags.isNotEmpty;
      case 3:
        return _profilePhotoBytes.isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canProceed()) {
      if (_currentIndex == 0 && _calculatedAge < 18) {
        _showToast('Bạn phải từ đủ 18 tuổi để tham gia DatingLy');
      } else if (_currentIndex == 0) {
        _showToast('Vui lòng nhập tên đầy đủ của bạn');
      } else if (_currentIndex == 2) {
        _showToast('Vui lòng chọn ít nhất 1 sở thích');
      } else if (_currentIndex == 3) {
        _showToast('Vui lòng tải lên ít nhất 1 ảnh hồ sơ');
      }
      return;
    }

    if (_currentIndex < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Đang chuẩn bị tải ảnh lên Storage...';
    });

    try {
      final profileVm = ref.read(profileViewModelProvider);
      final authVm = ref.read(authViewModelProvider.notifier);

      final List<String> uploadedUrls = [];

      for (int i = 0; i < _profilePhotoBytes.length; i++) {
        setState(() {
          _loadingStatus =
              'Đang nén & đẩy ảnh ${i + 1}/${_profilePhotoBytes.length} lên máy chủ...';
        });

        final url = await profileVm.uploadPhotoBytes(
          _profilePhotoBytes[i],
          folder: i == 0 ? 'avatars' : 'photos',
        );
        uploadedUrls.add(url);
      }

      setState(() {
        _loadingStatus = 'Đang lưu hồ sơ và thiết lập cấu hình...';
      });

      final success = await authVm.updateInitialProfile(
        fullName: _nameController.text.trim(),
        birthDate: _selectedBirthDate,
        age: _calculatedAge,
        gender: _gender,
        orientation: _orientation,
        bio: 'Chào mừng bạn đến với hồ sơ của mình! Hãy kết nối nhé ✨',
        tags: _selectedTags,
        avatarUrls: uploadedUrls,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Chào mừng bạn đến với DatingLy!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/discovery');
      } else {
        final err = ref.read(authViewModelProvider).errorMessage ??
            'Không thể hoàn tất hồ sơ. Vui lòng thử lại.';
        _showToast(err);
      }
    } catch (e) {
      if (mounted) _showToast('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepTitles = [
      'Thông tin cơ bản',
      'Giới tính & Định hướng',
      'Sở thích cá nhân',
      'Ảnh hồ sơ (Media)',
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      const BrandBanner(compact: true),
                      const SizedBox(height: 14),
                      Row(
                        children: List.generate(_totalSteps, (i) {
                          final isPassed = i < _currentIndex;
                          final isCurrent = i == _currentIndex;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              height: isCurrent ? 8 : 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: (isPassed || isCurrent)
                                    ? AppColors.primaryGradient
                                    : null,
                                color: (isPassed || isCurrent)
                                    ? null
                                    : Colors.grey[300],
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            stepTitles[_currentIndex],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Bước ${_currentIndex + 1}/$_totalSteps',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) =>
                        setState(() => _currentIndex = idx),
                    children: [
                      _buildStep1BasicInfo(),
                      _buildStep2GenderOrientation(),
                      _buildStep3Interests(),
                      _buildStep4MediaPhotos(),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentIndex > 0)
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isLoading ? null : _back,
                            child: const Text('Quay lại'),
                          ),
                        ),
                      if (_currentIndex > 0) const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: _canProceed()
                                ? AppColors.primaryGradient
                                : null,
                            color: _canProceed() ? null : Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _canProceed()
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isLoading ? null : _next,
                            child: Text(
                              _currentIndex == _totalSteps - 1
                                  ? 'Hoàn tất & Khám phá 🚀'
                                  : 'Tiếp tục',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _canProceed()
                                    ? Colors.white
                                    : Colors.grey[600],
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
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _loadingStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bạn tên là gì? 👋',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tên này sẽ hiển thị trên thẻ hồ sơ của bạn với người khác.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Họ và tên của bạn',
              hintText: 'Ví dụ: Bảo Khánh',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Ngày sinh của bạn 🎂',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tuổi sẽ được hiển thị công khai. Bạn phải từ 18 tuổi trở lên.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _calculatedAge < 18
                      ? AppColors.error
                      : AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBirthDate != null
                              ? '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}'
                              : 'Chưa chọn ngày sinh',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tuổi: $_calculatedAge tuổi',
                          style: TextStyle(
                            fontSize: 13,
                            color: _calculatedAge < 18
                                ? AppColors.error
                                : Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_calculatedAge < 18)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '🔞 Bạn phải đủ 18 tuổi để tham gia ứng dụng.',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2GenderOrientation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giới tính của bạn 👤',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: ProfileConstants.genders.map((g) {
              final isSelected = _gender == g;
              final emoji = g == 'Nam'
                  ? '👨'
                  : g == 'Nữ'
                      ? '👩'
                      : '🌈';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          g,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const Text(
            'Mục tiêu & Định hướng hẹn hò 🎯',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Chia sẻ kỳ vọng của bạn để tìm thấy người có cùng định hướng.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...ProfileConstants.datingIntentions.map((item) {
            final id = item['id']!;
            final isSelected = _orientation == id;

            return GestureDetector(
              onTap: () => setState(() => _orientation = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.25),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Text(item['emoji']!,
                        style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color:
                          isSelected ? AppColors.primary : Colors.grey[400],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStep3Interests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sở thích của bạn ✨',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Đã chọn: ${_selectedTags.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn ít nhất 1 sở thích để thuật toán kết nối người phù hợp.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  decoration: InputDecoration(
                    hintText: 'Thêm sở thích khác...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _addCustomTag(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _addCustomTag,
                child: const Text('Thêm'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...ProfileConstants.interestCategories.map((cat) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(cat.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        cat.categoryName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cat.tags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStep4MediaPhotos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ảnh hồ sơ (Media) 📸',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_profilePhotoBytes.length}/6 ảnh',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tải lên ít nhất 1 ảnh. Ảnh đầu tiên sẽ là ảnh đại diện chính. Bạn có thể cắt và sắp xếp thứ tự ảnh.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              final hasImage = index < _profilePhotoBytes.length;

              if (hasImage) {
                final bytes = _profilePhotoBytes[index];
                final isAvatar = index == 0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAvatar
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.5),
                          width: isAvatar ? 2.5 : 1,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvatar
                              ? AppColors.primary
                              : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAvatar ? '⭐️ Chính' : '#${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () => _recropPhoto(index),
                              child: const Icon(Icons.crop,
                                  color: Colors.white, size: 16),
                            ),
                            if (index > 0)
                              GestureDetector(
                                onTap: () => _movePhoto(index, index - 1),
                                child: const Icon(Icons.arrow_back,
                                    color: Colors.white, size: 16),
                              ),
                            if (index < _profilePhotoBytes.length - 1)
                              GestureDetector(
                                onTap: () => _movePhoto(index, index + 1),
                                child: const Icon(Icons.arrow_forward,
                                    color: Colors.white, size: 16),
                              ),
                            GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return GestureDetector(
                onTap: _pickAndProcessPhoto,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thêm ảnh',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mẹo có hồ sơ thu hút 💡',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chọn ảnh rõ mặt, nụ cười tươi và thể hiện sở thích của bạn (du lịch, cún mèo, thể thao). Ảnh được nén tự động để tải nhanh và tiết kiệm dung lượng.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


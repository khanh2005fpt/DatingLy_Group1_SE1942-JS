import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../viewmodels/profile_view_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const EditProfileScreen({super.key, this.initialProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customTagController = TextEditingController();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;
  late String _gender;
  late List<String> _selectedTags;

  // Avatar state
  XFile? _pickedAvatarFile;
  Uint8List? _pickedAvatarBytes;
  String? _currentAvatarUrl;

  // Profile photos state (không phải avatar)
  List<String> _existingPhotoUrls = [];   // URLs đã có trên server
  final List<XFile> _newPhotoFiles = [];
  final List<Uint8List> _newPhotoBytes = [];

  bool _isUploading = false;
  bool _isSaving = false;

  final List<String> _availableTags = [
    'Âm nhạc', 'Du lịch', 'Thể thao', 'Đọc sách',
    'Game', 'Thú cưng', 'Ẩm thực', 'Phim ảnh',
    'Yoga', 'Cà phê', 'Nghệ thuật', 'Thiên nhiên',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameController = TextEditingController(text: p?['full_name'] ?? '');
    _ageController = TextEditingController(text: p?['age']?.toString() ?? '');
    _bioController = TextEditingController(text: p?['bio'] ?? '');
    _gender = p?['gender'] ?? 'Nam';

    final rawTags = p?['tags'];
    _selectedTags = rawTags != null ? List<String>.from(rawTags) : [];

    final avatarUrls = p?['avatar_urls'];
    if (avatarUrls != null && (avatarUrls as List).isNotEmpty) {
      _currentAvatarUrl = avatarUrls[0] as String;
      // Các ảnh từ index 1 trở đi là profile photos
      if (avatarUrls.length > 1) {
        _existingPhotoUrls = List<String>.from(avatarUrls.sublist(1));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  // ─── Pick avatar ───
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedAvatarFile = picked;
        _pickedAvatarBytes = bytes;
      });
    }
  }

  // ─── Pick profile photos ───
  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _newPhotoFiles.add(picked);
        _newPhotoBytes.add(bytes);
      });
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() => _existingPhotoUrls.removeAt(index));
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotoFiles.removeAt(index);
      _newPhotoBytes.removeAt(index);
    });
  }

  // ─── Add custom tag ───
  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty) return;
    if (_selectedTags.contains(tag) || _availableTags.contains(tag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sở thích này đã tồn tại')),
      );
      return;
    }
    setState(() {
      _selectedTags.add(tag);
      _customTagController.clear();
    });
  }

  // ─── Save ───
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final profileVm = ref.read(profileViewModelProvider);

      // 1. Upload avatar mới (nếu có)
      String? newAvatarUrl;
      if (_pickedAvatarFile != null) {
        setState(() => _isUploading = true);
        newAvatarUrl = await profileVm.uploadAvatar(_pickedAvatarFile!);
      }

      // 2. Upload profile photos mới (nếu có)
      List<String> newPhotoUrls = [];
      for (final photoFile in _newPhotoFiles) {
        final url = await profileVm.uploadPhoto(photoFile);
        newPhotoUrls.add(url);
      }

      // 3. Cập nhật avatar_urls: [avatar, ...existingPhotos, ...newPhotos]
      final avatarUrl = newAvatarUrl ?? _currentAvatarUrl;
      final allUrls = [
        ?avatarUrl,
        ..._existingPhotoUrls,
        ...newPhotoUrls,
      ];

      // 4. Lưu thông tin hồ sơ
      await profileVm.updateProfile(
        fullName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 18,
        gender: _gender,
        bio: _bioController.text.trim(),
        tags: _selectedTags,
        avatarUrls: allUrls,
      );

      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cập nhật hồ sơ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || _isUploading) ? null : _save,
            child: _isSaving || _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ─── Avatar picker ───
            _buildSectionTitle('Ảnh đại diện'),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 3),
                        color: Colors.grey.withValues(alpha: 0.25),
                      ),
                      child: ClipOval(
                        child: _pickedAvatarBytes != null
                            ? Image.memory(_pickedAvatarBytes!,
                                fit: BoxFit.cover)
                            : _currentAvatarUrl != null
                                ? Image.network(_currentAvatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        ))
                                : const Icon(Icons.person,
                                    size: 60, color: Colors.grey),
                      ),
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.black38, shape: BoxShape.circle),
                          child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.primary),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('Nhấn để đổi ảnh đại diện',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            const SizedBox(height: 28),

            // ─── Profile Photos ───
            _buildSectionTitle('Ảnh trang cá nhân'),
            const SizedBox(height: 4),
            const Text('Thêm ảnh để mọi người hiểu bạn hơn',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            _buildPhotoGrid(),
            const SizedBox(height: 28),

            // ─── Họ tên ───
            _buildLabel('Tên hiển thị'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Tên của bạn', Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 20),

            // ─── Tuổi ───
            _buildLabel('Tuổi'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Tuổi của bạn', Icons.cake_outlined),
              validator: (v) {
                final age = int.tryParse(v ?? '');
                if (age == null || age < 18 || age > 100) {
                  return 'Tuổi phải từ 18 đến 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ─── Giới tính ───
            _buildLabel('Giới tính'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: _inputDecoration('Giới tính', Icons.wc_outlined),
              items: ['Nam', 'Nữ', 'Khác']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _gender = v);
              },
            ),
            const SizedBox(height: 20),

            // ─── Bio ───
            _buildLabel('Tiểu sử'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Viết gì đó thú vị về bản thân...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 64),
                  child:
                      Icon(Icons.edit_note_outlined, color: Colors.grey),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Tags / Sở thích ───
            _buildLabel('Sở thích (chọn nhiều)'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Predefined tags
                ..._allDisplayTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : null,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey[300]!),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            // Input thêm sở thích tuỳ chỉnh
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
                          borderRadius: BorderRadius.circular(30)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      isDense: true,
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
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // ─── Nút Lưu ───
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu thay đổi'),
                onPressed: (_isSaving || _isUploading) ? null : _save,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Tất cả tags để hiển thị = predefined + custom tags (không trùng predefined)
  List<String> get _allDisplayTags {
    final customTags = _selectedTags
        .where((t) => !_availableTags.contains(t))
        .toList();
    return [..._availableTags, ...customTags];
  }

  Widget _buildPhotoGrid() {
    final allPhotos = [
      ..._existingPhotoUrls.map((url) => _PhotoItem.network(url)),
      ..._newPhotoBytes
          .asMap()
          .entries
          .map((e) => _PhotoItem.memory(e.value, e.key)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: allPhotos.length + 1, // +1 cho nút thêm
      itemBuilder: (context, index) {
        if (index == allPhotos.length) {
          // Nút thêm ảnh
          return GestureDetector(
            onTap: _pickProfilePhoto,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                    width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.primary.withValues(alpha: 0.7), size: 32),
                  const SizedBox(height: 6),
                  Text('Thêm ảnh',
                      style: TextStyle(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final photo = allPhotos[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photo.isNetwork
                  ? Image.network(
                      photo.url!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (c, e, s) =>
                          Container(color: Colors.grey.withValues(alpha: 0.25)),
                    )
                  : Image.memory(
                      photo.bytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
            // Nút xóa
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  if (photo.isNetwork) {
                    _removeExistingPhoto(
                        _existingPhotoUrls.indexOf(photo.url!));
                  } else {
                    _removeNewPhoto(photo.memIndex!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: null));
  }

  Widget _buildLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: null));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }
}

/// Helper class để phân biệt ảnh từ network và ảnh local
class _PhotoItem {
  final bool isNetwork;
  final String? url;
  final Uint8List? bytes;
  final int? memIndex;

  _PhotoItem.network(this.url)
      : isNetwork = true,
        bytes = null,
        memIndex = null;

  _PhotoItem.memory(this.bytes, this.memIndex)
      : isNetwork = false,
        url = null;
}

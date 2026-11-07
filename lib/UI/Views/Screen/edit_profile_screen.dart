import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/profile_constants.dart';
import '../../../data/models/user_model.dart';
import '../../app_colors.dart';
import '../Widget/image_crop_compress_helper.dart';
import '../Widget/profile_prompts_editor.dart';
import '../../ViewModels/profile_view_model.dart';

class _PhotoItem {
  final String? url;
  Uint8List? bytes;

  _PhotoItem({this.url, this.bytes});
}

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const EditProfileScreen({super.key, this.initialProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _customTagController = TextEditingController();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late int _age;
  late String _gender;
  late String _orientation;
  late List<String> _selectedTags;
  late List<ProfilePrompt> _prompts;

  final List<_PhotoItem> _photos = [];
  bool _isSaving = false;
  String _savingStatus = '';

  int _previewPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        FocusScope.of(context).unfocus();
        setState(() {
          _previewPhotoIndex = 0;
        });
      }
    });

    final p = widget.initialProfile;
    _nameController = TextEditingController(text: p?['full_name'] ?? '');
    _bioController = TextEditingController(text: p?['bio'] ?? '');
    _age = (p?['age'] as num?)?.toInt() ?? 20;
    _gender = p?['gender'] ?? 'Nam';
    _orientation = p?['orientation'] ?? 'serious';

    final rawTags = p?['tags'];
    _selectedTags = rawTags != null ? List<String>.from(rawTags) : [];
    _prompts = ((p?['prompts'] as List?) ?? [])
        .map(ProfilePrompt.tryParse)
        .whereType<ProfilePrompt>()
        .toList();

    final avatarUrls = p?['avatar_urls'];
    if (avatarUrls != null && avatarUrls is List) {
      for (final u in avatarUrls) {
        if (u is String && u.isNotEmpty) {
          _photos.add(_PhotoItem(url: u));
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddPhoto() async {
    if (_photos.length >= 6) {
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

      final croppedBytes = await ImageCropCompressHelper.cropImage(
        context: context,
        sourcePath: picked.path,
        imageBytes: rawBytes,
        aspectRatio: 3 / 4,
      );

      if (croppedBytes != null && mounted) {
        final compressed =
            await ImageCropCompressHelper.compressImageBytes(croppedBytes);
        setState(() {
          _photos.add(_PhotoItem(bytes: compressed));
        });
        _showToast(
          'Đã thêm, cắt và nén ảnh thành công (${_photos.length}/6)',
          isSuccess: true,
        );
      }
    } catch (e) {
      _showToast('Lỗi khi thêm ảnh: $e');
    }
  }

  Future<void> _cropPhoto(int index) async {
    final photo = _photos[index];
    if (photo.bytes == null) {
      _showToast('Chỉ có thể cắt lại ảnh mới thêm trước khi lưu.');
      return;
    }

    final recropped = await ImageCropCompressHelper.cropImage(
      context: context,
      sourcePath: null,
      imageBytes: photo.bytes!,
      aspectRatio: 3 / 4,
    );

    if (recropped != null && mounted) {
      final compressed =
          await ImageCropCompressHelper.compressImageBytes(recropped);
      setState(() {
        photo.bytes = compressed;
      });
      _showToast('Đã cắt và nén lại ảnh #${index + 1}', isSuccess: true);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _movePhoto(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _photos.length) return;
    setState(() {
      final item = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, item);
    });
  }

  void _reorderPhoto(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _photos.length) return;
    if (newIndex < 0 || newIndex >= _photos.length) return;
    setState(() {
      final item = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, item);
    });
    _showToast(
      newIndex == 0
          ? 'Đã đặt làm ảnh đại diện chính ⭐️'
          : 'Đã kéo thả đổi thứ tự ảnh',
      isSuccess: true,
    );
  }

  void _setAsMainAvatar(int index) {
    if (index == 0 || index >= _photos.length) return;
    setState(() {
      final item = _photos.removeAt(index);
      _photos.insert(0, item);
    });
    _showToast('Đã đặt làm ảnh đại diện chính', isSuccess: true);
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty) return;
    if (_selectedTags.contains(tag)) {
      _showToast('Sở thích này đã tồn tại trong danh sách');
      return;
    }
    setState(() {
      _selectedTags.add(tag);
      _customTagController.clear();
    });
  }

  void _appendBioPrompt(String text) {
    final current = _bioController.text.trim();
    if (current.isEmpty) {
      _bioController.text = text;
    } else {
      _bioController.text = '$current\n$text';
    }
    setState(() {});
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      _showToast('Hồ sơ phải có ít nhất 1 ảnh đại diện.');
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = 'Đang chuẩn bị tải ảnh mới...';
    });

    try {
      final profileVm = ref.read(profileViewModelProvider);
      final List<String> finalUrls = [];

      for (int i = 0; i < _photos.length; i++) {
        final item = _photos[i];
        if (item.bytes != null) {
          setState(() {
            _savingStatus =
                'Đang nén & tải ảnh ${i + 1}/${_photos.length} lên máy chủ...';
          });
          final compressedBytes =
              await ImageCropCompressHelper.compressImageBytes(item.bytes!);
          final url = await profileVm.uploadPhotoBytes(
            compressedBytes,
            folder: i == 0 ? 'avatars' : 'photos',
          );
          finalUrls.add(url);
        } else if (item.url != null) {
          finalUrls.add(item.url!);
        }
      }

      setState(() {
        _savingStatus = 'Đang lưu thông tin cá nhân...';
      });

      await profileVm.updateProfile(
        fullName: _nameController.text.trim(),
        age: _age,
        gender: _gender,
        orientation: _orientation,
        bio: _bioController.text.trim(),
        tags: _selectedTags,
        avatarUrls: finalUrls,
        prompts: _prompts,
      );

      if (!mounted) return;
      _showToast('Cập nhật hồ sơ thành công!', isSuccess: true);
      context.pop();
    } catch (e) {
      if (mounted) _showToast('Lỗi khi lưu hồ sơ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Chỉnh sửa'),
            Tab(icon: Icon(Icons.remove_red_eye_rounded), text: 'Xem trước thẻ'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildEditTab(),
              _buildLivePreviewTab(),
            ],
          ),
          if (_isSaving)
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
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 18),
                      Text(
                        _savingStatus,
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
    );
  }

  Widget _buildEditTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ảnh hồ sơ (Tối đa 6 ảnh) 📸',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_photos.length}/6',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ảnh đầu tiên là ảnh đại diện. Bạn có thể nhấn giữ và kéo thả ảnh để đổi thứ tự.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kéo thả: Nhấn giữ 1 ảnh rồi kéo sang ô khác để đổi vị trí.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
              if (index < _photos.length) {
                final photo = _photos[index];
                final isAvatar = index == 0;

                return DragTarget<int>(
                  onWillAcceptWithDetails: (details) => details.data != index,
                  onAcceptWithDetails: (details) {
                    _reorderPhoto(details.data, index);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;
                    return LongPressDraggable<int>(
                      data: index,
                      delay: const Duration(milliseconds: 150),
                      feedback: Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 105,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.primary, width: 2.5),
                            image: photo.bytes != null
                                ? DecorationImage(
                                    image: MemoryImage(photo.bytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (photo.url != null
                                    ? DecorationImage(
                                        image: NetworkImage(photo.url!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildEditPhotoCard(photo, index, isAvatar),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: isHovered
                              ? Border.all(color: AppColors.primary, width: 3)
                              : null,
                        ),
                        child: _buildEditPhotoCard(photo, index, isAvatar),
                      ),
                    );
                  },
                );
              }

              return DragTarget<int>(
                onWillAcceptWithDetails: (details) => _photos.isNotEmpty,
                onAcceptWithDetails: (details) {
                  _reorderPhoto(details.data, _photos.length - 1);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;
                  return GestureDetector(
                    onTap: _pickAndAddPhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isHovered ? AppColors.primary : Colors.grey[300]!,
                          width: isHovered ? 2 : 1.5,
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
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
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
              );
            },
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tiểu sử (Bio) ✍️',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_bioController.text.length}/500',
                style: TextStyle(
                  fontSize: 12,
                  color: _bioController.text.length > 450
                      ? Colors.orange
                      : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Viết vài dòng giới thiệu bản thân, sở thích hay câu nói tâm đắc...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ProfileConstants.bioQuickPrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      prompt,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    onPressed: () => _appendBioPrompt(prompt),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Prompt hồ sơ 💬 (tối đa ${ProfileConstants.maxProfilePrompts})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn câu hỏi và trả lời, chúng sẽ hiển thị trên hồ sơ của bạn.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),
          ProfilePromptsEditor(
            initialPrompts: _prompts,
            onChanged: (list) => setState(() => _prompts = list),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sở thích theo danh mục ✨',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  decoration: InputDecoration(
                    hintText: 'Thêm sở thích riêng...',
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
          const SizedBox(height: 16),
          ...ProfileConstants.interestCategories.map((cat) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(cat.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        cat.categoryName,
                        style: const TextStyle(
                          fontSize: 14,
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
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
                const SizedBox(height: 12),
              ],
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Thông tin cơ bản & Định hướng 👤',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Họ và tên',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: InputDecoration(
              labelText: 'Giới tính',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: ProfileConstants.genders.map((g) {
              return DropdownMenuItem(value: g, child: Text(g));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _gender = val);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _orientation,
            decoration: InputDecoration(
              labelText: 'Mục tiêu / Định hướng hẹn hò',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: ProfileConstants.datingIntentions.map((item) {
              return DropdownMenuItem(
                value: item['id'],
                child: Text('${item['emoji']} ${item['title']}'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _orientation = val);
            },
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildEditPhotoCard(_PhotoItem photo, int index, bool isAvatar) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: photo.bytes != null
              ? Image.memory(photo.bytes!, fit: BoxFit.cover)
              : Image.network(
                  photo.url!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAvatar
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.6),
              width: isAvatar ? 2.5 : 1,
            ),
          ),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: GestureDetector(
            onTap: () => _setAsMainAvatar(index),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (photo.bytes != null)
                  GestureDetector(
                    onTap: () => _cropPhoto(index),
                    child: const Icon(Icons.crop,
                        color: Colors.white, size: 16),
                  ),
                if (index > 0)
                  GestureDetector(
                    onTap: () => _movePhoto(index, index - 1),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 16),
                  ),
                if (index < _photos.length - 1)
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

  Widget _buildLivePreviewTab() {
    final name = _nameController.text.trim().isEmpty
        ? 'Tên của bạn'
        : _nameController.text.trim();
    final bio = _bioController.text.trim().isEmpty
        ? 'Chưa có tiểu sử.'
        : _bioController.text.trim();

    final intentionObj = ProfileConstants.datingIntentions.firstWhere(
      (e) => e['id'] == _orientation,
      orElse: () => ProfileConstants.datingIntentions.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Nhấn nửa trái / phải của ảnh để xem các ảnh khác',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 520,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_photos.isNotEmpty)
                    _buildPreviewPhotoImage(_photos[_previewPhotoIndex])
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person,
                                size: 80, color: Colors.white70),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_photos.length > 1)
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (_previewPhotoIndex > 0) {
                                  setState(() => _previewPhotoIndex--);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (_previewPhotoIndex < _photos.length - 1) {
                                  setState(() => _previewPhotoIndex++);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length > 1)
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: List.generate(_photos.length, (i) {
                          return Expanded(
                            child: Container(
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: i == _previewPhotoIndex
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_age',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${intentionObj['emoji']} ${intentionObj['title']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedTags.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _selectedTags.take(4).map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_prompts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Về mình 💬',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            for (final p in _prompts)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.question,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(p.answer, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đây là giao diện thẻ quẹt mà các thành viên khác sẽ nhìn thấy khi khám phá bạn trên DatingLy.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPhotoImage(_PhotoItem item) {
    if (item.bytes != null) {
      return Image.memory(item.bytes!, fit: BoxFit.cover);
    }
    if (item.url != null) {
      return Image.network(
        item.url!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[400],
          child: const Icon(Icons.person, size: 80, color: Colors.white),
        ),
      );
    }
    return Container(color: Colors.grey[300]);
  }
}


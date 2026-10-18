import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/services/ai_service.dart';
import '../../../profile/presentation/screens/view_profile_screen.dart';
import '../utils/chat_time_format.dart';
import '../viewmodels/chat_view_model.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/emoji_panel.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String? otherUserName;
  final String? otherAvatarUrl;
  final String? otherBio;
  final List<String>? otherTags;

  const ChatScreen({
    super.key,
    required this.matchId,
    this.otherUserName,
    this.otherAvatarUrl,
    this.otherBio,
    this.otherTags,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final AiService _aiService = AiService();

  bool _showEmoji = false;

  ChatRoomViewModel get _viewModel =>
      ref.read(chatRoomViewModelProvider(widget.matchId).notifier);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Mở bàn phím thì đóng bảng emoji
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // List đảo ngược: maxScrollExtent là phía tin cũ nhất
  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _viewModel.loadOlder();
    }
  }

  void _scrollToLatest() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendText([String? preset]) {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _messageController.clear();
    _viewModel.sendText(text);
    _scrollToLatest();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Thu nhỏ + nén trước khi upload cho nhanh
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 75,
      );
      if (file == null) return;
      await _viewModel.sendImage(file);
      _scrollToLatest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không mở được ảnh: $e')));
      }
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _inputFocus.requestFocus(); // Quay lại bàn phím (listener tự đóng emoji)
    } else {
      _inputFocus.unfocus();
      setState(() => _showEmoji = true);
    }
  }

  void _insertEmoji(String emoji) {
    final value = _messageController.value;
    final start = value.selection.isValid ? value.selection.start : value.text.length;
    final end = value.selection.isValid ? value.selection.end : value.text.length;
    _messageController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _backspace() {
    final chars = _messageController.text.characters;
    if (chars.isEmpty) return;
    final text = chars.skipLast(1).toString();
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _openImage(MessageModel message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatImageViewer(
          imageUrl: message.content,
          heroTag: 'chat_image_${message.id}',
        ),
      ),
    );
  }

  void _showSmartOpener({
    required String bio,
    required List<String> tags,
    required List<MessageModel> messages,
  }) {
    String selectedStyle = 'Tự nhiên';
    final List<String> styles = [
      'Tự nhiên',
      'Hài hước',
      'Thả thính',
      'Lịch sự',
      'Quan tâm',
    ];
    List<String> suggestions = [];
    bool isFetching = false;

    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    final lastMsgs = messages.length > 10
        ? messages.sublist(messages.length - 10)
        : messages;
    final history = lastMsgs
        .map((m) =>
            '${m.senderId == myId ? "Tôi" : "Đối phương"}: ${m.isImage ? "[ảnh]" : m.content}')
        .join('\n');

    Future<void> fetchSuggestions(StateSetter setModalState) async {
      setModalState(() {
        isFetching = true;
        suggestions.clear();
      });

      final results = await _aiService.generateSuggestions(
        otherBio: bio,
        otherTags: tags,
        chatHistory: history,
        style: selectedStyle,
      );

      if (!mounted) return;
      setModalState(() {
        suggestions = results;
        isFetching = false;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Gọi AI lần đầu khi mở sheet
            if (suggestions.isEmpty && !isFetching) {
              // Dùng Future.microtask để tránh lỗi gọi setState trong lúc build
              Future.microtask(() => fetchSuggestions(setModalState));
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGradient.createShader(b),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Gợi ý tin nhắn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Phong cách:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: styles.map((s) {
                          final isSelected = s == selectedStyle;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : null,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                if (selected && s != selectedStyle) {
                                  selectedStyle = s;
                                  fetchSuggestions(setModalState);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isFetching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (suggestions.isNotEmpty)
                      ...suggestions.map((o) => _buildOpenerOption(o, ctx))
                    else
                      const Center(child: Text('Không có gợi ý nào.')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOpenerOption(String text, BuildContext sheetCtx) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(text, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(
          Icons.send_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        onTap: () {
          Navigator.pop(sheetCtx);
          _sendText(text);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = chatRoomViewModelProvider(widget.matchId);
    final room = ref.watch(provider);
    ref.listen(provider.select((s) => s.errorMessage), (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next)));
      }
    });

    // Mở từ thông báo thì không có extra -> lấy thông tin từ danh sách match
    final otherProfile = ref.watch(matchByIdProvider(widget.matchId))?.otherProfile;
    final name = widget.otherUserName?.isNotEmpty == true
        ? widget.otherUserName!
        : (otherProfile?.fullName.isNotEmpty == true
            ? otherProfile!.fullName
            : 'Người dùng');
    final avatarUrl = widget.otherAvatarUrl ?? otherProfile?.mainAvatarUrl;
    final bio = widget.otherBio ?? otherProfile?.bio ?? '';
    final tags = widget.otherTags ?? otherProfile?.tags ?? const <String>[];
    final myId = ref.watch(firebaseAuthServiceProvider).currentUser?.uid;

    void openSmartOpener() =>
        _showSmartOpener(bio: bio, tags: tags, messages: room.messages);

    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _showEmoji = false); // Back = đóng emoji trước
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: InkWell(
            onTap: () {
              final profileData = otherProfile?.toMap() ??
                  {
                    'full_name': name,
                    if (avatarUrl != null && avatarUrl.isNotEmpty)
                      'avatar_urls': [avatarUrl],
                    'bio': bio,
                    'tags': tags,
                  };
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewProfileScreen(profile: profileData),
                ),
              );
            },
            child: Row(
              children: [
                ChatAvatar(url: avatarUrl, name: name, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Chạm để xem hồ sơ',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.gamepad_outlined, color: AppColors.primary),
              onPressed: () => context.push('/minigame'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _inputFocus.unfocus();
                  if (_showEmoji) setState(() => _showEmoji = false);
                },
                child: _buildMessageList(
                  room: room,
                  myId: myId,
                  name: name,
                  avatarUrl: avatarUrl,
                  onSmartOpener: openSmartOpener,
                ),
              ),
            ),
            if (room.isUploadingImage)
              const Column(
                children: [
                  LinearProgressIndicator(color: AppColors.primary),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Đang gửi ảnh...',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            _buildMessageInput(room, openSmartOpener),
            if (_showEmoji)
              EmojiPanel(
                onEmojiSelected: _insertEmoji,
                onBackspace: _backspace,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList({
    required ChatRoomState room,
    required String? myId,
    required String name,
    required String? avatarUrl,
    required VoidCallback onSmartOpener,
  }) {
    if (room.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final messages = room.messages;
    if (messages.isEmpty) {
      return _buildEmptyChat(name, avatarUrl, onSmartOpener);
    }

    final lastMyIndex = messages.lastIndexWhere((m) => m.senderId == myId);

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Tin mới nhất ở dưới, bàn phím mở không che tin cuối
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: messages.length + 1,
      itemBuilder: (context, i) {
        if (i == messages.length) return _buildListTop(room);

        final index = messages.length - 1 - i;
        final msg = messages[index];
        final prev = index > 0 ? messages[index - 1] : null;
        final next = index < messages.length - 1 ? messages[index + 1] : null;
        final date = msg.createdAt ?? DateTime.now();
        final showDate = prev == null ||
            !ChatTimeFormat.isSameDay(prev.createdAt ?? date, date);
        final groupedWithNext = next != null &&
            next.senderId == msg.senderId &&
            ChatTimeFormat.isSameDay(next.createdAt ?? date, date);
        final isMe = msg.senderId == myId;

        return Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showDate) ChatDateDivider(date: date),
            MessageBubble(
              key: ValueKey(msg.id),
              message: msg,
              isMe: isMe,
              showStatusLabel: isMe && index == lastMyIndex,
              groupedWithNext: groupedWithNext,
              onImageTap: msg.isImage ? () => _openImage(msg) : null,
            ),
          ],
        );
      },
    );
  }

  /// Đầu danh sách (phía trên cùng): đang tải tin cũ / đã hết tin
  Widget _buildListTop(ChatRoomState room) {
    if (room.isLoadingOlder) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!room.hasMoreOlder) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Text('Bắt đầu cuộc trò chuyện',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  Widget _buildEmptyChat(
      String name, String? avatarUrl, VoidCallback onSmartOpener) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatAvatar(url: avatarUrl, name: name, radius: 48),
            const SizedBox(height: 16),
            Text(
              'Bạn và $name đã tương hợp!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy là người đầu tiên gửi lời chào 👋',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: ['👋', 'Chào bạn! 😊', 'Rất vui được làm quen ❤️']
                  .map((text) => ActionChip(
                        label: Text(text),
                        onPressed: () => _sendText(text),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Gợi ý từ AI'),
              onPressed: onSmartOpener,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ChatRoomState room, VoidCallback onSmartOpener) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            spreadRadius: 1,
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: !_showEmoji, // Bảng emoji đã tự chừa SafeArea
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppColors.primary),
              tooltip: 'Gửi ảnh',
              onPressed: room.isUploadingImage ? null : _showAttachSheet,
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
              tooltip: 'AI gợi ý câu hỏi',
              onPressed: onSmartOpener,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showEmoji
                          ? Icons.keyboard_alt_outlined
                          : Icons.emoji_emotions_outlined,
                      color: Colors.grey[600],
                    ),
                    onPressed: _toggleEmoji,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, _) {
                final canSend = value.text.trim().isNotEmpty;
                return IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: canSend ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: canSend ? _sendText : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

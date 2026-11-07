import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/ai_repository.dart';
import '../../../data/repositories/app_providers.dart';
import '../../ViewModels/chat_view_model.dart';
import '../Widget/chat_avatar_widget.dart';
import '../Widget/emoji_panel_widget.dart';
import '../Widget/message_bubble_widget.dart';
import 'view_profile_screen.dart';

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
  final AiRepository _aiRepository = AiRepository();
  final ImagePicker _picker = ImagePicker();

  bool _showEmoji = false;
  bool _isUploadingImage = false;

  // Optimistic messages: Tin nhắn vừa gửi đang chờ xác nhận từ server
  final List<MessageModel> _optimisticMessages = [];

  // Lịch sử tin nhắn gần nhất phục vụ AI gợi ý ngữ cảnh
  List<MessageModel> _latestMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatViewModelProvider).markAsRead(widget.matchId);
    });

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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final myId = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    final optimistic = MessageModel(
      id: tempId,
      matchId: widget.matchId,
      senderId: myId,
      content: text,
      messageType: MessageModel.typeText,
      isPending: true,
      createdAt: DateTime.now(),
    );

    setState(() => _optimisticMessages.add(optimistic));
    _scrollToBottom();

    try {
      await ref.read(chatViewModelProvider).sendMessage(
            matchId: widget.matchId,
            content: text,
          );
      if (mounted) {
        setState(
          () => _optimisticMessages.removeWhere((m) => m.id == tempId),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tin: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);

    try {
      await ref.read(chatViewModelProvider).sendImageMessage(
            matchId: widget.matchId,
            imageFile: picked,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _openImageViewer(String imageUrl, String heroTag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatImageViewer(imageUrl: imageUrl, heroTag: heroTag),
      ),
    );
  }

  void _openOtherProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profile: {
            'full_name': widget.otherUserName ?? 'Người ấy',
            'bio': widget.otherBio ?? '',
            'tags': widget.otherTags ?? [],
            'avatar_urls':
                widget.otherAvatarUrl != null ? [widget.otherAvatarUrl!] : [],
          },
        ),
      ),
    );
  }

  void _showSmartOpener() {
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

    Future<void> fetchSuggestions(StateSetter setModalState) async {
      setModalState(() {
        isFetching = true;
        suggestions.clear();
      });

      final bio = widget.otherBio ?? '';
      final tags = widget.otherTags ?? [];

      String history = '';
      final lastMsgs = _latestMessages.length > 10
          ? _latestMessages.sublist(_latestMessages.length - 10)
          : _latestMessages;
      final myId = ref.read(authRepositoryProvider).currentUser?.uid;

      for (var m in lastMsgs) {
        final isMe = m.senderId == myId;
        history += '${isMe ? "Tôi" : "Đối phương"}: ${m.content}\n';
      }

      final results = await _aiRepository.generateSuggestions(
        otherBio: bio,
        otherTags: tags,
        style: selectedStyle,
        chatHistory: history,
      );

      setModalState(() {
        isFetching = false;
        suggestions = results;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = Theme.of(modalCtx).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AI Gợi ý câu mở lời & trò chuyện',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(modalCtx).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Chọn phong cách trò chuyện:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: styles.map((style) {
                      final isSelected = style == selectedStyle;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(style),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedStyle = style);
                              fetchSuggestions(setModalState);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (suggestions.isEmpty && !isFetching)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => fetchSuggestions(setModalState),
                      icon: const Icon(Icons.psychology),
                      label: const Text('Bấm để tạo gợi ý'),
                    ),
                  ),
                if (isFetching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                if (suggestions.isNotEmpty && !isFetching) ...[
                  Text(
                    'Chạm vào câu bạn thích để áp dụng:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        return InkWell(
                          onTap: () {
                            _messageController.text = suggestions[i];
                            Navigator.pop(modalCtx);
                            _inputFocus.requestFocus();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    suggestions[i],
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.north_west,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.matchId));
    final currentUserId =
        ref.watch(authStateChangesProvider).value?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openOtherProfile,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                ChatAvatar(
                  url: widget.otherAvatarUrl,
                  name: widget.otherUserName ?? '?',
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUserName ?? 'Người dùng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Tương hợp',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            tooltip: 'Thư viện ảnh',
            onPressed: () => context.push(
              '/settings/media-gallery/${widget.matchId}',
              extra: {'otherUserName': widget.otherUserName},
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'report') {
                context.push('/settings/safety');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Báo cáo người dùng', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sports_esports),
            tooltip: 'Minigame',
            onPressed: () => context.push('/minigame'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Xem hồ sơ',
            onPressed: _openOtherProfile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploadingImage)
            const LinearProgressIndicator(
              color: AppColors.primary,
              minHeight: 2,
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Lỗi tải tin nhắn: $err'),
                ),
              ),
              data: (serverMessages) {
                // Hợp nhất tin nhắn server và tin nhắn optimistic
                final allMessages = [...serverMessages, ..._optimisticMessages];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _latestMessages = allMessages;
                    final hasUnread = serverMessages.any(
                      (m) => m.senderId != currentUserId && !m.isRead,
                    );
                    if (hasUnread) {
                      ref
                          .read(chatViewModelProvider)
                          .markAsRead(widget.matchId);
                    }
                  }
                });

                if (allMessages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 64,
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hãy là người đầu tiên gửi tin!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gửi một lời chào hoặc dùng trợ lý AI gợi ý câu mở đầu thật ấn tượng.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text('Gợi ý từ AI'),
                            onPressed: _showSmartOpener,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final msg = allMessages[index];
                    final isMe = msg.senderId == currentUserId;
                    final isLast = index == allMessages.length - 1;

                    // Kiểm tra ngày với tin nhắn trước đó để chèn Date Divider
                    bool showDateDivider = false;
                    if (index == 0) {
                      showDateDivider = true;
                    } else {
                      final prevDate = allMessages[index - 1].createdAt;
                      final currDate = msg.createdAt;
                      if (prevDate != null && currDate != null) {
                        showDateDivider = prevDate.day != currDate.day ||
                            prevDate.month != currDate.month ||
                            prevDate.year != currDate.year;
                      }
                    }

                    // Gom nhóm tin nhắn liên tiếp cùng người gửi
                    bool groupedWithNext = false;
                    if (index < allMessages.length - 1) {
                      groupedWithNext =
                          allMessages[index + 1].senderId == msg.senderId;
                    }

                    return Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (showDateDivider && msg.createdAt != null)
                          ChatDateDivider(date: msg.createdAt!),
                        GestureDetector(
                          onLongPress: () {
                            if (!msg.isImage) {
                              Clipboard.setData(
                                ClipboardData(text: msg.content),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép tin nhắn'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          child: MessageBubble(
                            message: msg,
                            isMe: isMe,
                            showStatusLabel: isMe && isLast,
                            groupedWithNext: groupedWithNext,
                            onImageTap: msg.isImage
                                ? () => _openImageViewer(
                                      msg.content,
                                      'chat_image_${msg.id}',
                                    )
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
          if (_showEmoji)
            EmojiPanel(
              onEmojiSelected: (emoji) {
                final text = _messageController.text;
                final sel = _messageController.selection;
                final start = sel.start >= 0 ? sel.start : text.length;
                final end = sel.end >= 0 ? sel.end : text.length;
                final newText = text.replaceRange(start, end, emoji);
                _messageController.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: start + emoji.length,
                  ),
                );
              },
              onBackspace: () {
                final text = _messageController.text;
                if (text.isEmpty) return;
                final sel = _messageController.selection;
                final start = sel.start > 0 ? sel.start : text.length;
                final end = sel.end > 0 ? sel.end : text.length;
                if (start == end) {
                  final chars = text.characters;
                  if (chars.isNotEmpty) {
                    final newChars = chars.take(chars.length - 1).toString();
                    _messageController.value = TextEditingValue(
                      text: newChars,
                      selection: TextSelection.collapsed(
                        offset: newChars.length,
                      ),
                    );
                  }
                } else {
                  final newText = text.replaceRange(start, end, '');
                  _messageController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: start),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
              onPressed: _showSmartOpener,
              tooltip: 'AI Gợi ý câu mở lời',
            ),
            IconButton(
              icon: Icon(
                _showEmoji
                    ? Icons.keyboard_alt_outlined
                    : Icons.emoji_emotions_outlined,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: () {
                setState(() => _showEmoji = !_showEmoji);
                if (_showEmoji) {
                  _inputFocus.unfocus();
                } else {
                  _inputFocus.requestFocus();
                }
              },
              tooltip: 'Biểu tượng cảm xúc',
            ),
            IconButton(
              icon: Icon(
                Icons.photo_library_outlined,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: _pickAndSendImage,
              tooltip: 'Gửi ảnh',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocus,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF2F2F2),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                maxLines: null,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _sendMessage,
              tooltip: 'Gửi',
            ),
          ],
        ),
      ),
    );
  }
}

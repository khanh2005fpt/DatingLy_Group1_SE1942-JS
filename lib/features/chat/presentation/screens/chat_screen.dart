import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/services/ai_service.dart';
import '../../../profile/presentation/screens/view_profile_screen.dart';
import '../viewmodels/chat_view_model.dart';

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
  final AiService _aiService = AiService();
  final bool _isAiLoading = false;

  // Optimistic messages: tin nhắn gửi nhưng chưa có phản hồi từ server
  final List<Map<String, dynamic>> _optimisticMessages = [];

  // Cập nhật để lưu lịch sử chat cho AI
  List<Map<String, dynamic>> _latestMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatViewModelProvider).markAsRead(widget.matchId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    // Optimistic update: hiển thị tin nhắn ngay
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {
      'id': tempId,
      'match_id': widget.matchId,
      'sender_id': myId,
      'content': text,
      'message_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
      '_isOptimistic': true,
    };
    setState(() => _optimisticMessages.add(optimistic));
    _scrollToBottom();

    try {
      await ref.read(chatViewModelProvider).sendMessage(
            matchId: widget.matchId,
            content: text,
          );
      // Xóa tin nhắn optimistic sau khi server xác nhận (stream sẽ tự cập nhật)
      setState(() => _optimisticMessages.removeWhere((m) => m['id'] == tempId));
    } catch (e) {
      // Đánh dấu lỗi
      setState(() {
        final idx = _optimisticMessages.indexWhere((m) => m['id'] == tempId);
        if (idx != -1) _optimisticMessages[idx]['_error'] = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi gửi tin: $e')));
      }
    }
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
      final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
      for (var m in lastMsgs) {
        final isMe = m['sender_id'] == myId;
        history += '${isMe ? "Tôi" : "Đối phương"}: ${m['content']}\n';
      }

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
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.black87,
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
      color: Colors.grey[50],
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
          _messageController.text = text;
          _sendMessage();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    String? currentUserId,
    bool isLastMyMessage,
  ) {
    final isMe = msg['sender_id'] == currentUserId;
    final isOptimistic = msg['_isOptimistic'] == true;
    final isError = msg['_error'] == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? (isError
                          ? Colors.redAccent
                          : isOptimistic
                          ? AppColors.primary.withValues(alpha: 0.75)
                          : AppColors.primary)
                    : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                msg['content'],
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
            if (isOptimistic && !isError)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 2),
                    Text(
                      'Đang gửi...',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
            else if (isMe && !isError && isLastMyMessage)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      msg['is_read'] == true ? Icons.done_all : Icons.done,
                      size: 12,
                      color: msg['is_read'] == true
                          ? Colors.blue
                          : Colors.grey[400],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      msg['is_read'] == true ? 'Đã xem' : 'Đã gửi',
                      style: TextStyle(
                        fontSize: 10,
                        color: msg['is_read'] == true
                            ? Colors.blue
                            : Colors.grey[400],
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(firebaseAuthServiceProvider).currentUser?.uid;
    final name = widget.otherUserName ?? 'Người dùng';
    final avatarUrl = widget.otherAvatarUrl;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            final profileData = {
              'full_name': name,
              if (avatarUrl != null) 'avatar_urls': [avatarUrl],
              'bio': widget.otherBio,
              'tags': widget.otherTags,
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
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Đang hoạt động',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
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
            child: Builder(
              builder: (context) {
                final messagesAsync = ref.watch(messagesStreamProvider(widget.matchId));
                final serverModelList = messagesAsync.value ?? [];
                final serverMessages = serverModelList.map((m) => {
                  'id': m.id,
                  'match_id': m.matchId,
                  'sender_id': m.senderId,
                  'content': m.content,
                  'message_type': m.messageType,
                  'is_read': m.isRead,
                  'created_at': m.createdAt?.toIso8601String(),
                }).toList();

                // Gộp server messages + optimistic messages, tránh duplicate
                final serverIds = serverMessages.map((m) => m['id']).toSet();
                final pendingOptimistic = _optimisticMessages
                    .where((m) => !serverIds.contains(m['id']))
                    .toList();
                final allMessages = [...serverMessages, ...pendingOptimistic];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _latestMessages = allMessages;

                    // Đánh dấu đã đọc nếu có tin nhắn mới từ đối phương
                    final hasUnread = allMessages.any(
                      (m) =>
                          m['sender_id'] != currentUserId &&
                          m['is_read'] != true,
                    );
                    if (hasUnread) {
                      ref.read(chatViewModelProvider).markAsRead(widget.matchId);
                    }
                  }
                });

                if (messagesAsync.isLoading && allMessages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Hãy là người đầu tiên gửi tin!',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Gợi ý từ AI'),
                          onPressed: _showSmartOpener,
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                final isMyAbsoluteLastMessage =
                    allMessages.isNotEmpty &&
                    allMessages.last['sender_id'] == currentUserId;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final isLast = index == allMessages.length - 1;
                    return _buildMessageBubble(
                      allMessages[index],
                      currentUserId,
                      isLast && isMyAbsoluteLastMessage,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            spreadRadius: 1,
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: _isAiLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, color: AppColors.primary),
              onPressed: _isAiLoading ? null : _showSmartOpener,
              tooltip: 'AI gợi ý câu hỏi',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
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
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

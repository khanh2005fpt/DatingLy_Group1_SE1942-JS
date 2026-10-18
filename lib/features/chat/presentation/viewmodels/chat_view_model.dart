import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/services/chat_cache_service.dart';
import '../../../../data/services/chat_service.dart';

// StreamProvider danh sách Matches
final matchesStreamProvider = StreamProvider<List<MatchModel>>((ref) {
  // Theo dõi auth state để stream tự đổi khi đăng nhập/đăng xuất
  final myId = ref.watch(authStateChangesProvider).value?.uid;
  final chat = ref.watch(chatServiceProvider);

  if (myId == null) return Stream.value([]);
  return chat.streamMatches(myId);
});

/// Tìm 1 match trong danh sách (dùng khi mở chat từ thông báo, không có extra).
final matchByIdProvider = Provider.family<MatchModel?, String>((ref, matchId) {
  final matches = ref.watch(matchesStreamProvider).value ?? const [];
  for (final m in matches) {
    if (m.id == matchId) return m;
  }
  return null;
});

class ChatRoomState {
  final List<MessageModel> messages; // Tăng dần theo thời gian
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMoreOlder;
  final bool isUploadingImage;
  final String? errorMessage;

  const ChatRoomState({
    this.messages = const [],
    this.isLoading = true,
    this.isLoadingOlder = false,
    this.hasMoreOlder = true,
    this.isUploadingImage = false,
    this.errorMessage,
  });

  ChatRoomState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMoreOlder,
    bool? isUploadingImage,
    String? errorMessage,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      errorMessage: errorMessage,
    );
  }
}

/// ViewModel cho 1 phòng chat ([matchId] là tham số của family).
///
/// Tin nhắn hiển thị = tin trong cache SQLite / trang cũ đã tải
///                    + [pageSize] tin mới nhất nghe realtime từ Firestore.
/// Cache luôn giữ 1 đoạn liền mạch tới hiện tại, nên tin cũ chỉ đọc Firestore 1 lần.
class ChatRoomViewModel extends Notifier<ChatRoomState> {
  ChatRoomViewModel(this.matchId);

  static const int pageSize = 30;

  final String matchId;

  final Map<String, MessageModel> _loaded = {}; // Tin từ cache / trang cũ
  List<MessageModel> _live = const []; // Tin realtime mới nhất
  bool _cacheSynced = false; // Cache đã liền mạch -> được ghi tin realtime vào
  bool _isMarkingRead = false;
  bool _markReadAgain = false;

  ChatService get _chat => ref.read(chatServiceProvider);
  ChatCacheService get _cache => ref.read(chatCacheServiceProvider);
  String? get _myId => ref.read(firebaseAuthServiceProvider).currentUser?.uid;

  @override
  ChatRoomState build() {
    final sub = _chat
        .streamLatestMessages(matchId, limit: pageSize)
        .listen(_onLiveMessages, onError: (Object e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Lỗi tải tin nhắn: $e');
    });
    ref.onDispose(sub.cancel);

    Future.microtask(_restoreFromCache);
    Future.microtask(_markAsRead); // Xoá badge chưa đọc ngay khi mở chat
    return const ChatRoomState();
  }

  Future<void> _restoreFromCache() async {
    try {
      final cached = await _cache.getLatestMessages(matchId, limit: pageSize);
      if (!ref.mounted) return;

      if (cached.isEmpty) {
        // Chưa có cache: đoạn realtime chính là điểm bắt đầu của cache
        _cacheSynced = true;
        await _cache.upsertMessages(_live);
        return;
      }

      for (final m in cached) {
        _loaded[m.id] = m;
      }
      _emit();

      // Bù các tin tới sau lần mở chat trước để cache không bị hở
      final missing =
          await _chat.fetchMessagesAfter(matchId, cached.last.createdAt!);
      await _cache.upsertMessages(missing);
      _cacheSynced = true;
      await _cache.upsertMessages(_live);
      if (!ref.mounted) return;

      for (final m in missing) {
        _loaded[m.id] = m;
      }
      _emit();
    } catch (e) {
      debugPrint('Chat cache restore error: $e');
    }
  }

  void _onLiveMessages(List<MessageModel> messages) {
    _live = messages;
    if (_cacheSynced) _cache.upsertMessages(messages);
    // Cả cuộc trò chuyện nằm gọn trong đoạn realtime -> không còn tin cũ hơn
    if (messages.length < pageSize) {
      state = state.copyWith(hasMoreOlder: false);
    }
    _emit();

    final myId = _myId;
    if (messages.any((m) => m.senderId != myId && !m.isRead)) {
      _markAsRead();
    }
  }

  void _emit() {
    final merged = <String, MessageModel>{..._loaded};
    for (final m in _live) {
      merged[m.id] = m;
    }
    final list = merged.values.toList()
      ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    state = state.copyWith(messages: list, isLoading: false);
  }

  /// Tải thêm tin cũ: ưu tiên SQLite, thiếu thì mới đọc Firestore.
  Future<void> loadOlder() async {
    if (state.isLoadingOlder || !state.hasMoreOlder || state.messages.isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingOlder: true);

    try {
      final oldest = state.messages.first.createdAt!;
      final older =
          await _cache.getMessagesBefore(matchId, oldest, limit: pageSize);

      var hasMore = true;
      final need = pageSize - older.length;
      if (need > 0) {
        final from = older.isNotEmpty ? older.first.createdAt! : oldest;
        final remote =
            await _chat.fetchMessagesBefore(matchId, from, limit: need);
        if (_cacheSynced) await _cache.upsertMessages(remote);
        older.insertAll(0, remote);
        hasMore = remote.length == need;
      }
      if (!ref.mounted) return;

      for (final m in older) {
        _loaded[m.id] = m;
      }
      state = state.copyWith(isLoadingOlder: false, hasMoreOlder: hasMore);
      _emit();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
          isLoadingOlder: false, errorMessage: 'Lỗi tải tin cũ: $e');
    }
  }

  Future<void> sendText(String text) async {
    final myId = _myId;
    final content = text.trim();
    if (myId == null || content.isEmpty) return;

    try {
      await _chat.sendMessage(
          matchId: matchId, senderId: myId, content: content);
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: 'Gửi tin thất bại: $e');
      }
    }
  }

  Future<void> sendImage(XFile file) async {
    final myId = _myId;
    if (myId == null) return;

    state = state.copyWith(isUploadingImage: true);
    try {
      final url = await ref
          .read(firebaseStorageServiceProvider)
          .uploadChatImage(matchId: matchId, imageFile: file);
      if (!ref.mounted) return;
      state = state.copyWith(isUploadingImage: false);

      await _chat.sendMessage(
        matchId: matchId,
        senderId: myId,
        content: url,
        type: MessageModel.typeImage,
      );
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
            isUploadingImage: false, errorMessage: 'Gửi ảnh thất bại: $e');
      }
    }
  }

  Future<void> _markAsRead() async {
    final myId = _myId;
    if (myId == null) return;
    if (_isMarkingRead) {
      _markReadAgain = true; // Có tin mới tới trong lúc đang đánh dấu
      return;
    }

    _isMarkingRead = true;
    try {
      await _chat.markMessagesAsRead(matchId: matchId, myId: myId);
    } catch (e) {
      debugPrint('Mark as read error: $e');
    } finally {
      _isMarkingRead = false;
    }

    if (_markReadAgain && ref.mounted) {
      _markReadAgain = false;
      await _markAsRead();
    }
  }
}

/// autoDispose: rời màn chat thì huỷ stream. Còn tồn tại = đang mở chat đó.
final chatRoomViewModelProvider = NotifierProvider.autoDispose
    .family<ChatRoomViewModel, ChatRoomState, String>(ChatRoomViewModel.new);

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/match_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';

part 'chat_view_model.g.dart';

// Stream danh sách Matches
@Riverpod(keepAlive: true)
Stream<List<MatchModel>> matchesStream(Ref ref) {
  final myId = ref.watch(authStateChangesProvider).value?.uid;
  final chatRepo = ref.watch(chatRepositoryProvider);

  if (myId == null) return Stream.value([]);
  return chatRepo.streamMatches(myId);
}

// Stream tin nhắn theo matchId (autoDispose: chỉ tồn tại khi đang mở phòng chat,
// notification_bootstrap dựa vào ref.exists để biết có đang mở phòng đó không)
@riverpod
Stream<List<MessageModel>> messagesStream(Ref ref, String matchId) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.streamMessages(matchId);
}

class ChatViewModel {
  final ChatRepository _chatRepo;
  final AuthRepository _authRepo;

  ChatViewModel({
    required ChatRepository chatRepo,
    required AuthRepository authRepo,
  })  : _chatRepo = chatRepo,
        _authRepo = authRepo;

  Future<void> sendMessage({
    required String matchId,
    required String content,
    String type = 'text',
  }) async {
    final myId = _authRepo.currentUser?.uid;
    if (myId == null || content.trim().isEmpty) return;

    await _chatRepo.sendMessage(
      matchId: matchId,
      senderId: myId,
      content: content.trim(),
      type: type,
    );
  }

  Future<void> markAsRead(String matchId) async {
    final myId = _authRepo.currentUser?.uid;
    if (myId == null) return;

    await _chatRepo.markMessagesAsRead(
      matchId: matchId,
      myId: myId,
    );
  }
}

@Riverpod(keepAlive: true)
ChatViewModel chatViewModel(Ref ref) {
  return ChatViewModel(
    chatRepo: ref.watch(chatRepositoryProvider),
    authRepo: ref.watch(authRepositoryProvider),
  );
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/services/firebase_auth_service.dart';
import '../../../../data/services/firestore_service.dart';

// StreamProvider danh sách Matches
final matchesStreamProvider = StreamProvider<List<MatchModel>>((ref) {
  // Theo dõi auth state để stream tự đổi khi đăng nhập/đăng xuất
  final myId = ref.watch(authStateChangesProvider).value?.uid;
  final firestore = ref.watch(firestoreServiceProvider);

  if (myId == null) return Stream.value([]);
  return firestore.streamMatches(myId);
});

// StreamProvider danh sách tin nhắn theo matchId
final messagesStreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, matchId) {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.streamMessages(matchId);
});

class ChatViewModel {
  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;

  ChatViewModel({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
  })  : _firestoreService = firestoreService,
        _authService = authService;

  Future<void> sendMessage({
    required String matchId,
    required String content,
    String type = 'text',
  }) async {
    final myId = _authService.currentUser?.uid;
    if (myId == null || content.trim().isEmpty) return;

    await _firestoreService.sendMessage(
      matchId: matchId,
      senderId: myId,
      content: content.trim(),
      type: type,
    );
  }

  Future<void> markAsRead(String matchId) async {
    final myId = _authService.currentUser?.uid;
    if (myId == null) return;

    await _firestoreService.markMessagesAsRead(
      matchId: matchId,
      myId: myId,
    );
  }
}

final chatViewModelProvider = Provider<ChatViewModel>((ref) {
  return ChatViewModel(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
  );
});

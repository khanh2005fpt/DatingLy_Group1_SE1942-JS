import 'user_model.dart';

class WhoLikedUserItem {
  final UserModel user;
  final DateTime? likedAt;
  final bool isMatched;
  final bool isSuperLike;

  const WhoLikedUserItem({
    required this.user,
    this.likedAt,
    this.isMatched = false,
    this.isSuperLike = false,
  });

  WhoLikedUserItem copyWith({
    UserModel? user,
    DateTime? likedAt,
    bool? isMatched,
    bool? isSuperLike,
  }) {
    return WhoLikedUserItem(
      user: user ?? this.user,
      likedAt: likedAt ?? this.likedAt,
      isMatched: isMatched ?? this.isMatched,
      isSuperLike: isSuperLike ?? this.isSuperLike,
    );
  }
}


import 'package:flutter/material.dart';

/// Bảng emoji thay cho bàn phím (không cần thêm package ngoài).
class EmojiPanel extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspace;

  const EmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
  });

  static const List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
    '🙂', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘',
    '😗', '😚', '😋', '😛', '😜', '🤪', '😝', '🤗',
    '🤭', '🤫', '🤔', '😐', '😶', '😏', '😒', '🙄',
    '😬', '😌', '😔', '😪', '😴', '😷', '🥵', '🥶',
    '😎', '🤓', '😕', '😟', '🙁', '😮', '😯', '😲',
    '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😢',
    '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫',
    '😤', '😡', '😠', '🤯', '🥳', '😈', '💀', '👻',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '💔', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤙', '👋',
    '👏', '🙌', '🙏', '💪', '🫶', '🔥', '✨', '🌹',
    '🎉', '🎁', '☕', '🍕', '🍻', '🎵', '🌙', '⭐',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 280,
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 46,
                ),
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onEmojiSelected(emoji),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined),
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

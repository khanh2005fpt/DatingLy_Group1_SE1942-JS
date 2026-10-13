import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // Key nạp qua: flutter run --dart-define=GEMINI_API_KEY=xxx (không commit key vào mã nguồn)
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _modelName = 'gemini-2.5-flash-lite';
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final GenerativeModel _model;

  AiService() : _model = GenerativeModel(model: _modelName, apiKey: apiKey);

  Future<List<String>> generateSuggestions({
    required String otherBio,
    required List<String> otherTags,
    required String chatHistory,
    required String style,
  }) async {
    if (apiKey.isEmpty) {
      return [
        'Vui lòng chạy app với --dart-define=GEMINI_API_KEY=<key>.',
        'Mock: (Phong cách $style) Chào bạn, rất vui được làm quen.',
        'Mock: Sở thích của bạn là gì?',
      ];
    }

    final hasHistory = chatHistory.trim().isNotEmpty;
    final contextPrompt = hasHistory
        ? 'Hai người đang trò chuyện. Dưới đây là lịch sử các tin nhắn gần nhất:\n'
              '$chatHistory\n\nHãy gợi ý câu tiếp theo để trả lời hoặc tiếp nối câu chuyện.'
        : 'Đây là lần đầu tiên hai người nhắn tin. Hãy gợi ý câu mở lời tinh tế '
              'để bắt đầu cuộc trò chuyện.';

    final prompt =
        '''
Bạn là một AI hỗ trợ ứng dụng hẹn hò. Người dùng đang muốn nhắn tin với một người có thông tin sau:
- Tiểu sử (Bio): $otherBio
- Sở thích: ${otherTags.join(", ")}

$contextPrompt

Yêu cầu:
- Phong cách nhắn tin: $style
- Hãy tạo ra đúng 3 câu gợi ý bằng Tiếng Việt có dấu chuẩn xác.
- Tự nhiên, không quá dài dòng.
- Mỗi câu trên một dòng riêng biệt, không đánh số thứ tự và không dùng ngoặc kép.
''';

    final content = [Content.text(prompt)];

    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final response = await _model.generateContent(content);
        final suggestions = _parseSuggestions(response.text ?? '');

        if (suggestions.isNotEmpty) {
          return suggestions.take(3).toList();
        }

        throw StateError('Gemini tra ve noi dung rong.');
      } catch (error) {
        final canRetry = attempt < _retryDelays.length && _shouldRetry(error);
        if (!canRetry) {
          break;
        }
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    return _buildFallbackSuggestions(
      style: style,
      chatHistory: chatHistory,
      otherTags: otherTags,
    );
  }

  List<String> _parseSuggestions(String text) {
    return text
        .split('\n')
        .map(
          (line) => line
              .trim()
              .replaceAll(RegExp(r'^[-*]\s*'), '')
              .replaceAll(RegExp(r'^\d+\.\s*'), ''),
        )
        .where((line) => line.isNotEmpty)
        .toList();
  }

  bool _shouldRetry(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('503') ||
        message.contains('unavailable') ||
        message.contains('high demand') ||
        message.contains('overloaded') ||
        message.contains('timeout') ||
        message.contains('deadline exceeded');
  }

  List<String> _buildFallbackSuggestions({
    required String style,
    required String chatHistory,
    required List<String> otherTags,
  }) {
    final hasHistory = chatHistory.trim().isNotEmpty;
    final firstTag = otherTags.isNotEmpty
        ? otherTags.first
        : 'những điều bạn thích';

    if (hasHistory) {
      switch (style) {
        case 'Hài hước':
          return [
            'Nghe cuốn quá, kể thêm cho mình một đoạn nữa đi?',
            'Câu chuyện này đang hay đấy, phần tiếp theo là gì vậy?',
            'Mình đang bị cuốn vào đây rồi, bạn kể tiếp nhé?',
          ];
        case 'Thả thính':
          return [
            'Nói chuyện với bạn xong tự nhiên mình thấy hôm nay dễ thương hơn đó.',
            'Bạn cứ rep kiểu này là mình muốn nói chuyện mãi thôi.',
            'Càng nói chuyện mình càng thấy bạn có sức hút đó.',
          ];
        case 'Lịch sự':
          return [
            'Mình thấy câu chuyện này khá thú vị, bạn chia sẻ thêm được không?',
            'Cách bạn nói chuyện làm mình rất thoải mái, mình muốn nghe thêm.',
            'Bạn đang nhắc đến một điều khá hay, bạn kể tiếp nhé?',
          ];
        case 'Quan tâm':
          return [
            'Nghe vậy mình thấy điều đó chắc hẳn có ý nghĩa với bạn, cảm xúc của bạn lúc đó thế nào?',
            'Chi tiết đó làm mình tò mò, điều gì khiến bạn ấn tượng nhất vậy?',
            'Mình muốn hiểu bạn hơn một chút, bạn kể tiếp cho mình nghe nhé?',
          ];
        default:
          return [
            'Nghe hay thật, bạn kể thêm cho mình nghe được không?',
            'Mình thấy câu chuyện này khá thú vị đó, rồi sao nữa nhỉ?',
            'Bạn nói chuyện cuốn thật, mình muốn nghe tiếp.',
          ];
      }
    }

    switch (style) {
      case 'Hài hước':
        return [
          'Chào bạn, nếu nói về $firstTag thì bạn thuộc team chuyên gia hay team cảm tính vậy?',
          'Mình thấy vibe của bạn khá thú vị, mở đầu bằng chuyện $firstTag có bị lố đê không?',
          'Hello bạn, cho mình hỏi nhé: với $firstTag thì bạn có phải người rất khó tính không?',
        ];
      case 'Thả thính':
        return [
          'Chào bạn, mình ghé qua và thấy bạn để lại ấn tượng khá mạnh đó.',
          'Mình nghĩ bắt đầu cuộc trò chuyện với bạn là quyết định đúng đắn đấy.',
          'Hi bạn, một lời chào dễ thương chắc hợp với bạn hơn là mở bài quá nghiêm túc.',
        ];
      case 'Lịch sự':
        return [
          'Chào bạn, mình rất vui được làm quen. Bạn thường quan tâm nhất đến $firstTag phải không?',
          'Xin chào, mình thấy hồ sơ của bạn khá thú vị, đặc biệt là phần $firstTag.',
          'Rất vui được kết nối với bạn. Điều gì ở $firstTag khiến bạn thích nhất vậy?',
        ];
      case 'Quan tâm':
        return [
          'Chào bạn, mình tò mò điều gì trong $firstTag khiến bạn thấy vui nhất?',
          'Hi bạn, nếu được chọn một điều để kể về bản thân, bạn sẽ bắt đầu từ $firstTag chứ?',
          'Mình thấy $firstTag khá hợp để mở đầu câu chuyện, bạn nghĩ sao?',
        ];
      default:
        return [
          'Chào bạn, rất vui được làm quen.',
          'Mình thấy hồ sơ của bạn khá thú vị, đặc biệt là phần $firstTag.',
          'Nếu bắt đầu bằng một chủ đề nhẹ nhàng, mình muốn nghe bạn kể về $firstTag.',
        ];
    }
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  int currentQuestion = 0;
  final List<Map<String, String>> questions = [
    {'optionA': 'Trà', 'optionB': 'Cà phê'},
    {'optionA': 'Chó', 'optionB': 'Mèo'},
    {'optionA': 'Biển', 'optionB': 'Núi'},
    {'optionA': 'Sách', 'optionB': 'Phim'},
  ];

  int matchCount = 0;

  void _answer(String choice) {
    // Giả lập đối phương cũng chọn ngẫu nhiên
    final isMatch = DateTime.now().millisecond % 2 == 0;
    if (isMatch) matchCount++;

    if (currentQuestion < questions.length - 1) {
      setState(() => currentQuestion++);
    } else {
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Kết quả Mini-game', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hai bạn có $matchCount/${questions.length} điểm chung!', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Hệ thống đã gửi kết quả vào khung chat để làm chủ đề mở lời.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Quay lại chat
            },
            child: const Text('Quay lại chat'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentQuestion >= questions.length) return const Scaffold();

    final q = questions[currentQuestion];

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('This or That', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Câu ${currentQuestion + 1}/${questions.length}',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildOption(q['optionA']!, Colors.blue),
                  _buildOption(q['optionB']!, Colors.orange),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String text, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _answer(text),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

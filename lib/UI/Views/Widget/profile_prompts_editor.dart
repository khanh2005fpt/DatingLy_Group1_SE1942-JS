import 'package:flutter/material.dart';

import '../../../data/models/profile_constants.dart';
import '../../../data/models/user_model.dart';
import '../../app_colors.dart';

/// Ô nhập prompt hồ sơ (câu hỏi + câu trả lời), dùng chung cho onboarding và edit profile.
/// Chỉ báo về [onChanged] những prompt đã có câu trả lời.
class ProfilePromptsEditor extends StatefulWidget {
  final List<ProfilePrompt> initialPrompts;
  final ValueChanged<List<ProfilePrompt>> onChanged;

  const ProfilePromptsEditor({
    super.key,
    this.initialPrompts = const [],
    required this.onChanged,
  });

  @override
  State<ProfilePromptsEditor> createState() => _ProfilePromptsEditorState();
}

class _PromptEntry {
  String question;
  final TextEditingController controller;

  _PromptEntry(this.question, String answer)
      : controller = TextEditingController(text: answer);
}

class _ProfilePromptsEditorState extends State<ProfilePromptsEditor> {
  final List<_PromptEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    for (final p in widget.initialPrompts
        .take(ProfileConstants.maxProfilePrompts)) {
      _entries.add(_PromptEntry(p.question, p.answer));
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.controller.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      _entries
          .where((e) => e.controller.text.trim().isNotEmpty)
          .map((e) => ProfilePrompt(
                question: e.question,
                answer: e.controller.text.trim(),
              ))
          .toList(),
    );
  }

  List<String> _availableQuestions(_PromptEntry current) {
    final used = _entries
        .where((e) => e != current)
        .map((e) => e.question)
        .toSet();
    final options = ProfileConstants.promptQuestions
        .where((q) => !used.contains(q))
        .toList();
    // Giữ lại câu hỏi hiện có (ví dụ dữ liệu cũ không nằm trong danh sách gợi ý)
    if (!options.contains(current.question)) options.insert(0, current.question);
    return options;
  }

  void _addEntry() {
    if (_entries.length >= ProfileConstants.maxProfilePrompts) return;
    final used = _entries.map((e) => e.question).toSet();
    final next = ProfileConstants.promptQuestions
        .firstWhere((q) => !used.contains(q),
            orElse: () => ProfileConstants.promptQuestions.first);
    setState(() => _entries.add(_PromptEntry(next, '')));
  }

  void _removeEntry(_PromptEntry entry) {
    setState(() => _entries.remove(entry));
    entry.controller.dispose();
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in _entries) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: entry.question,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        items: _availableQuestions(entry)
                            .map((q) => DropdownMenuItem(
                                  value: q,
                                  child: Text(q,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (q) {
                          if (q == null) return;
                          setState(() => entry.question = q);
                          _notify();
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa prompt',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _removeEntry(entry),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextField(
                    controller: entry.controller,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: ProfileConstants.maxPromptAnswerLength,
                    onChanged: (_) => _notify(),
                    decoration: InputDecoration(
                      hintText: 'Câu trả lời của bạn...',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_entries.length < ProfileConstants.maxProfilePrompts)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _addEntry,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Thêm câu hỏi (${_entries.length}/${ProfileConstants.maxProfilePrompts})',
            ),
          ),
      ],
    );
  }
}

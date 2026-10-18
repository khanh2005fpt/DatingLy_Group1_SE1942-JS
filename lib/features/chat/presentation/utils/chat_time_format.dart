/// Định dạng thời gian cho màn chat / danh sách hội thoại.
class ChatTimeFormat {
  static const List<String> _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 14:05
  static String clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// Nhãn ngăn cách ngày trong khung chat: Hôm nay / Hôm qua / 12/10/2026
  static String dayLabel(DateTime t) {
    final now = DateTime.now();
    if (isSameDay(t, now)) return 'Hôm nay';
    if (isSameDay(t, now.subtract(const Duration(days: 1)))) return 'Hôm qua';
    return '${_two(t.day)}/${_two(t.month)}/${t.year}';
  }

  /// Thời gian ở danh sách hội thoại: 14:05 / Hôm qua / T4 / 12/10
  static String listTime(DateTime t) {
    final now = DateTime.now();
    if (isSameDay(t, now)) return clock(t);
    if (isSameDay(t, now.subtract(const Duration(days: 1)))) return 'Hôm qua';
    if (now.difference(t).inDays < 7) return _weekdays[t.weekday - 1];
    return '${_two(t.day)}/${_two(t.month)}';
  }
}

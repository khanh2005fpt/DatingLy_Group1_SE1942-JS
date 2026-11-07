class CategoryInterests {
  final String categoryName;
  final String icon;
  final List<String> tags;

  const CategoryInterests({
    required this.categoryName,
    required this.icon,
    required this.tags,
  });
}

class ProfileConstants {
  static const List<CategoryInterests> interestCategories = [
    CategoryInterests(
      categoryName: 'Âm nhạc',
      icon: '🎵',
      tags: [
        'Pop',
        'Indie',
        'Rap / Hip-hop',
        'Rock',
        'K-Pop',
        'R&B',
        'EDM',
        'Jazz',
        'Acoustic',
        'Nhạc Trịnh',
      ],
    ),
    CategoryInterests(
      categoryName: 'Thể thao & Vận động',
      icon: '🏃',
      tags: [
        'Gym & Fitness',
        'Chạy bộ',
        'Yoga',
        'Cầu lông',
        'Bơi lội',
        'Bóng đá',
        'Leo núi',
        'Đạp xe',
        'Pickleball',
        'Bóng rổ',
      ],
    ),
    CategoryInterests(
      categoryName: 'Ẩm thực & Thức uống',
      icon: '🍜',
      tags: [
        'Nấu ăn',
        'Cà phê',
        'Trà sữa',
        'Street food',
        'Bánh ngọt',
        'Rượu vang',
        'Healthy food',
        'Lẩu & Nướng',
      ],
    ),
    CategoryInterests(
      categoryName: 'Phong cách & Du lịch',
      icon: '✈️',
      tags: [
        'Du lịch',
        'Phượt xe máy',
        'Cắm trại',
        'Đọc sách',
        'Nuôi mèo',
        'Nuôi cún',
        'Chụp ảnh',
        'Thời trang',
        'Khám phá quán mới',
      ],
    ),
    CategoryInterests(
      categoryName: 'Giải trí & Nghệ thuật',
      icon: '🎮',
      tags: [
        'Xem phim rạp',
        'Chơi game',
        'Boardgame',
        'Vẽ tranh',
        'Podcast',
        'Bảo tàng & Triển lãm',
        'Đi dạo đêm',
        'Nhạc sống',
      ],
    ),
  ];

  static const List<Map<String, String>> datingIntentions = [
    {
      'id': 'serious',
      'title': 'Hẹn hò nghiêm túc',
      'emoji': '💍',
      'subtitle': 'Tìm kiếm một mối quan hệ bền vững, hướng tới tương lai',
    },
    {
      'id': 'long_term',
      'title': 'Tìm hiểu lâu dài',
      'emoji': '❤️',
      'subtitle': 'Tìm hiểu từ từ, tôn trọng cảm xúc và chân thành',
    },
    {
      'id': 'casual',
      'title': 'Gặp gỡ & Đi chơi',
      'emoji': '☕',
      'subtitle': 'Hẹn hò nhẹ nhàng, cà phê nói chuyện và trải nghiệm',
    },
    {
      'id': 'friends',
      'title': 'Tìm bạn tâm sự',
      'emoji': '💬',
      'subtitle': 'Chia sẻ niềm vui nỗi buồn, mở rộng vòng bạn bè',
    },
    {
      'id': 'open',
      'title': 'Để xem thế nào',
      'emoji': '✨',
      'subtitle': 'Mọi thứ cứ để tự nhiên, sẵn sàng đón nhận điều thú vị',
    },
  ];

  static const List<String> genders = ['Nam', 'Nữ', 'Khác'];

  /// Số prompt tối đa mỗi người được hiển thị trên hồ sơ.
  static const int maxProfilePrompts = 3;
  static const int maxPromptAnswerLength = 150;

  /// Câu hỏi gợi ý cho prompt hồ sơ (user chọn 1 câu rồi tự trả lời).
  static const List<String> promptQuestions = [
    'Điều khiến mình vui nhất cuối tuần là…',
    'Một điều ít ai biết về mình…',
    'Buổi hẹn đầu tiên lý tưởng của mình là…',
    'Mình sẽ không từ chối lời mời đi…',
    'Điều mình tìm kiếm ở một nửa kia là…',
    'Bài hát mình nghe đi nghe lại gần đây…',
    'Cách nhanh nhất để làm mình cười là…',
    'Ước mơ lớn nhất của mình là…',
  ];

  static const List<String> bioQuickPrompts = [
    'Thích cà phê sáng và những buổi đi dạo đêm ☕',
    'Yêu động vật, đặc biệt là boss mèo 🐾',
    'Mê du lịch phượt và khám phá ẩm thực đường phố ✈️',
    'Người hướng ngoại nhưng thích một góc yên tĩnh đọc sách 📖',
    'Tìm người cùng nghe nhạc Indie và đi ăn kem 🍦',
  ];
}


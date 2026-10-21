import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tạo / xoá dữ liệu giả để test Discovery (chỉ dùng ở debug build).
///
/// User giả có id cố định `seed_000` … `seed_029` và cờ `is_seed: true`,
/// nên xoá được sạch mà không đụng tới user thật.
class SeedService {
  static const int count = 30;
  static const String _prefix = 'seed_';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _id(int i) => '$_prefix${i.toString().padLeft(3, '0')}';

  static const _femaleNames = [
    'Linh', 'Trang', 'Hương', 'Mai', 'Lan', 'Thảo', 'Ngọc', 'Hà', 'Yến',
    'Phương', 'Nhung', 'Vy', 'Chi', 'Quỳnh', 'Thu',
  ];
  static const _maleNames = [
    'Minh', 'Hùng', 'Nam', 'Tuấn', 'Long', 'Khoa', 'Dũng', 'Bảo', 'Phúc',
    'Đạt', 'Sơn', 'Hải', 'Quân', 'Việt', 'Thành',
  ];
  static const _lastNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Vũ'];
  static const _tags = [
    'Âm nhạc', 'Du lịch', 'Thể thao', 'Đọc sách', 'Game', 'Thú cưng',
    'Ẩm thực', 'Phim ảnh', 'Yoga', 'Cà phê', 'Nghệ thuật', 'Thiên nhiên',
  ];
  static const _bios = [
    'Thích đi đây đi đó và thử món mới.',
    'Cà phê sáng, sách tối.',
    'Tìm một người cùng đi bộ cuối tuần.',
    'Hay cười, hơi lười, rất thật lòng.',
    'Mê nấu ăn và những chuyến đi bất chợt.',
  ];
  static const _prompts = [
    ['Điều khiến mình cười nhất', 'Mèo của mình ngủ ngáy to hơn cả mình.'],
    ['Cuối tuần lý tưởng', 'Cà phê, một cuốn sách và không ai làm phiền.'],
    ['Mình sẽ không từ chối', 'Một chuyến đi biển nói đi là đi.'],
    ['Kỹ năng vô dụng nhất', 'Nhớ lời bài hát từ năm 2010.'],
    ['Buổi hẹn đầu tiên', 'Đi dạo rồi ăn kem, đơn giản vậy thôi.'],
  ];

  /// Tạo [count] user giả quanh [center]; [likeMeCount] người đầu tiên đã Like [myId].
  Future<void> seed({
    required String myId,
    GeoPoint? center,
    int likeMeCount = 5,
  }) async {
    final rnd = Random();
    final c = center ?? const GeoPoint(21.0278, 105.8342); // Hà Nội
    final batch = _db.batch();

    for (var i = 0; i < count; i++) {
      final isFemale = i.isEven;
      final gender = i % 7 == 0 ? 'Khác' : (isFemale ? 'Nữ' : 'Nam');
      final first = isFemale
          ? _femaleNames[rnd.nextInt(_femaleNames.length)]
          : _maleNames[rnd.nextInt(_maleNames.length)];
      final name = '${_lastNames[rnd.nextInt(_lastNames.length)]} $first';

      // Lệch vị trí ~0–80 km (1 độ ≈ 111 km)
      final dLat = (rnd.nextDouble() - 0.5) * 1.4;
      final dLon = (rnd.nextDouble() - 0.5) * 1.4;

      final tags = [..._tags]..shuffle(rnd);
      final picks = (_prompts.toList()..shuffle(rnd)).take(2);
      final portrait = isFemale ? 'women' : 'men';
      final photoNo = (i ~/ 2) % 90;

      batch.set(_db.collection('users').doc(_id(i)), {
        'id': _id(i),
        'email': '${_id(i)}@seed.test',
        'full_name': name,
        'age': 19 + rnd.nextInt(22),
        'gender': gender,
        'bio': _bios[rnd.nextInt(_bios.length)],
        'tags': tags.take(3 + rnd.nextInt(3)).toList(),
        'avatar_urls': [
          'https://randomuser.me/api/portraits/$portrait/$photoNo.jpg',
          'https://randomuser.me/api/portraits/$portrait/${(photoNo + 1) % 90}.jpg',
        ],
        'location': GeoPoint(c.latitude + dLat, c.longitude + dLon),
        'prompts': picks
            .map((p) => {'question': p[0], 'answer': p[1]})
            .toList(),
        'is_seed': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Vài người đã Like mình sẵn để thử "Ai đã thích bạn" và match
      if (i < likeMeCount) {
        batch.set(_db.collection('swipes').doc('${_id(i)}_$myId'), {
          'swiper_id': _id(i),
          'swiped_id': myId,
          'action': i == 0 ? 'super_like' : 'like',
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  /// Xoá toàn bộ user giả, swipes giữa mình và họ, và match nếu có.
  Future<void> clear({required String myId}) async {
    final batch = _db.batch();
    for (var i = 0; i < count; i++) {
      final id = _id(i);
      batch.delete(_db.collection('users').doc(id));
      batch.delete(_db.collection('swipes').doc('${myId}_$id'));
      batch.delete(_db.collection('swipes').doc('${id}_$myId'));
      final ids = [myId, id]..sort();
      batch.delete(_db.collection('matches').doc(ids.join('_')));
    }
    await batch.commit();
  }
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_prm/data/repositories/photo_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoCodec', () {
    test('isDataUri nhận diện data URI ảnh và bỏ qua URL http', () {
      expect(PhotoCodec.isDataUri('data:image/jpeg;base64,AAAA'), isTrue);
      expect(PhotoCodec.isDataUri('https://example.com/a.jpg'), isFalse);
      expect(PhotoCodec.isDataUri(''), isFalse);
    });

    test('encode ảnh nhỏ ra data URI và decode lại đúng dữ liệu', () async {
      // Trong môi trường test không có plugin nén ảnh nên codec dùng dữ liệu gốc.
      final bytes = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      final uri = await PhotoCodec.encode(bytes);

      expect(uri.startsWith('data:image/jpeg;base64,'), isTrue);
      expect(uri.length, lessThanOrEqualTo(PhotoCodec.maxEncodedLength));
      expect(PhotoCodec.decode(uri), bytes);
    });

    test('encode ném lỗi khi ảnh vẫn vượt giới hạn dung lượng sau khi nén', () async {
      final huge = Uint8List(PhotoCodec.maxEncodedLength * 2);
      await expectLater(PhotoCodec.encode(huge), throwsException);
    });
  });
}

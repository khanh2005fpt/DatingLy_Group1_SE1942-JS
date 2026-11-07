import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Mã hóa / giải mã ảnh hồ sơ dạng data URI (`data:image/jpeg;base64,...`)
/// để lưu thẳng trong Firestore, thay cho Firebase Storage (không cần gói Blaze).
///
/// Mỗi document Firestore tối đa 1 MiB, và ảnh nằm trong `avatar_urls` của document
/// `users`, nên mỗi ảnh bị giới hạn [maxEncodedLength] ký tự (6 ảnh ≈ 720 KB).
class PhotoCodec {
  PhotoCodec._();

  static const int maxEncodedLength = 120000;
  static const String _prefix = 'data:image/jpeg;base64,';

  /// (cạnh rộng tối đa, chất lượng JPEG) thử từ nét nhất đến nhẹ nhất.
  static const List<(int, int)> _attempts = [
    (720, 78),
    (640, 68),
    (540, 58),
    (440, 48),
    (360, 40),
  ];

  static bool isDataUri(String url) => url.startsWith('data:image/');

  /// Nén ảnh và trả về data URI không vượt quá [maxEncodedLength] ký tự.
  static Future<String> encode(Uint8List bytes) async {
    for (final (width, quality) in _attempts) {
      final compressed = await _compress(bytes, width, quality);
      final encoded = '$_prefix${base64Encode(compressed)}';
      if (encoded.length <= maxEncodedLength) return encoded;
    }
    throw Exception(
      'Ảnh quá lớn để lưu trong Firestore. Vui lòng chọn ảnh khác hoặc cắt nhỏ lại.',
    );
  }

  static Future<Uint8List> _compress(
    Uint8List bytes,
    int width,
    int quality,
  ) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: width,
        minHeight: (width * 4 / 3).round(),
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (out.isNotEmpty) return out;
    } catch (e) {
      debugPrint('PhotoCodec: flutter_image_compress lỗi, dùng dữ liệu gốc: $e');
    }
    return bytes;
  }

  // Giải mã base64 tốn CPU và ảnh được build lại nhiều lần, nên giữ cache nhỏ (LRU).
  static final Map<String, Uint8List> _cache = {};
  static const int _cacheSize = 48;

  /// Giải mã data URI thành bytes ảnh (có cache).
  static Uint8List decode(String dataUri) {
    final cached = _cache.remove(dataUri);
    if (cached != null) {
      _cache[dataUri] = cached;
      return cached;
    }
    final bytes = base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));
    _cache[dataUri] = bytes;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return bytes;
  }
}

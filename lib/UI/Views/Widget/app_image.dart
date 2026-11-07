import 'package:flutter/widgets.dart';
import '../../../data/repositories/photo_codec.dart';

/// ImageProvider dùng chung cho ảnh hồ sơ: hỗ trợ cả data URI (base64 lưu trong Firestore)
/// lẫn URL http(s) (ví dụ dữ liệu seed).
///
/// Dùng thay cho `NetworkImage(url)`, và `Image(image: appImageProvider(url))`
/// thay cho `Image.network(url)`.
ImageProvider appImageProvider(String url) {
  if (PhotoCodec.isDataUri(url)) {
    return MemoryImage(PhotoCodec.decode(url));
  }
  return NetworkImage(url);
}

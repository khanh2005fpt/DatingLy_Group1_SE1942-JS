import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';

/// Cache tin nhắn offline bằng SQLite: mở chat là thấy tin cũ ngay,
/// tin cũ đã có trong máy thì không phải đọc lại từ Firestore.
///
/// Trên web / Windows / Linux (sqflite không hỗ trợ) mọi hàm đều là no-op.
class ChatCacheService {
  static const String _dbName = 'chat_cache.db';
  static const String _table = 'messages';

  Future<Database?>? _dbFuture;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<Database?> get _db => _dbFuture ??= _open();

  Future<Database?> _open() async {
    if (!isSupported) return null;
    try {
      final path = p.join(await getDatabasesPath(), _dbName);
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_table (
              id TEXT PRIMARY KEY,
              match_id TEXT NOT NULL,
              sender_id TEXT NOT NULL,
              content TEXT NOT NULL,
              message_type TEXT NOT NULL,
              is_read INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_messages_match_time ON $_table (match_id, created_at)');
        },
      );
    } catch (e) {
      debugPrint('ChatCacheService open error: $e');
      return null;
    }
  }

  /// [limit] tin mới nhất của match (tăng dần theo thời gian).
  Future<List<MessageModel>> getLatestMessages(String matchId,
      {int limit = 30}) async {
    final db = await _db;
    if (db == null) return [];
    final rows = await db.query(
      _table,
      where: 'match_id = ?',
      whereArgs: [matchId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(MessageModel.fromCacheMap).toList().reversed.toList();
  }

  /// [limit] tin cũ hơn [before] (tăng dần theo thời gian).
  Future<List<MessageModel>> getMessagesBefore(String matchId, DateTime before,
      {int limit = 30}) async {
    final db = await _db;
    if (db == null) return [];
    final rows = await db.query(
      _table,
      where: 'match_id = ? AND created_at < ?',
      whereArgs: [matchId, before.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(MessageModel.fromCacheMap).toList().reversed.toList();
  }

  /// Lưu / cập nhật tin nhắn. Bỏ qua tin còn pending vì chưa có giờ server.
  Future<void> upsertMessages(Iterable<MessageModel> messages) async {
    final db = await _db;
    if (db == null) return;
    final batch = db.batch();
    for (final m in messages) {
      if (m.isPending) continue;
      batch.insert(_table, m.toCacheMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Xoá toàn bộ cache (gọi khi đăng xuất).
  Future<void> clearAll() async {
    final db = await _db;
    if (db == null) return;
    await db.delete(_table);
  }
}

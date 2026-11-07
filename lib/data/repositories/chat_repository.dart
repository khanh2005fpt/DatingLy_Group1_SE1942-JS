import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/match_model.dart';
import '../models/message_model.dart';
import 'data_helper.dart';
import 'user_repository.dart';

/// ChatRepository: Quản lý collection matches, subcollection/collection messages
/// và tích hợp SQLite Local Cache (PRM393 MVVM Pattern).
class ChatRepository {
  static const String _dbName = 'chat_cache.db';
  static const String _table = 'messages';

  final DataHelper _helper = DataHelper();
  final UserRepository _userRepo = UserRepository();

  Future<Database?>? _dbFuture;

  bool get _isSqfliteSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<Database?> get _db => _dbFuture ??= _openDb();

  Future<Database?> _openDb() async {
    if (!_isSqfliteSupported) return null;
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
            'CREATE INDEX idx_messages_match_time ON $_table (match_id, created_at)',
          );
        },
      );
    } catch (e) {
      debugPrint('ChatRepository SQLite open error: $e');
      return null;
    }
  }

  // ==================== MATCHES ====================

  Stream<List<MatchModel>> streamMatches(String myId) {
    return _helper.matchesCol
        .where('users', arrayContains: myId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<MatchModel> list = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final otherId = data['user1_id'] == myId
            ? (data['user2_id'] as String)
            : (data['user1_id'] as String);

        final otherProfile = await _userRepo.getUserProfile(otherId);

        final msgs =
            await _helper.messagesCol.where('match_id', isEqualTo: doc.id).get();
        final unread = msgs.docs.where((m) {
          final d = m.data();
          return d['sender_id'] != myId && d['is_read'] != true;
        }).length;

        list.add(MatchModel.fromMap(
          data,
          doc.id,
          otherProfile: otherProfile,
        ).copyWith(unreadCount: unread));
      }

      list.sort((a, b) => (b.lastMessageTime ?? DateTime(0))
          .compareTo(a.lastMessageTime ?? DateTime(0)));
      return list;
    });
  }

  // ==================== MESSAGES & REALTIME ====================

  Stream<List<MessageModel>> streamMessages(String matchId) {
    return _helper.messagesCol
        .where('match_id', isEqualTo: matchId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

      // Lưu/cập nhật cache SQLite ở background
      upsertMessagesToCache(list);

      return list;
    });
  }

  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String content,
    String type = MessageModel.typeText,
  }) async {
    final preview = type == MessageModel.typeImage ? '📷 Ảnh' : content;

    await _helper.messagesCol.add({
      'match_id': matchId,
      'sender_id': senderId,
      'content': content,
      'message_type': type,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    await _helper.matchesCol.doc(matchId).update({
      'last_message': preview,
      'last_sender_id': senderId,
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }

  /// Upload ảnh đính kèm trong tin nhắn lên Firebase Storage
  Future<String> uploadChatImage({
    required String matchId,
    required XFile imageFile,
  }) async {
    final ext = imageFile.name.split('.').last.toLowerCase();
    final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref =
        _helper.storage.ref().child('chats').child(matchId).child(fileName);

    final bytes = await imageFile.readAsBytes();
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$ext'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> markMessagesAsRead({
    required String matchId,
    required String myId,
  }) async {
    final snap =
        await _helper.messagesCol.where('match_id', isEqualTo: matchId).get();
    final unread = snap.docs.where((d) {
      final data = d.data();
      return data['sender_id'] != myId && data['is_read'] != true;
    });
    if (unread.isEmpty) return;

    final batch = _helper.firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

  // ==================== SQLITE LOCAL CACHE ====================

  /// Lấy danh sách tin nhắn từ bộ nhớ cục bộ SQLite
  Future<List<MessageModel>> getCachedMessages(
    String matchId, {
    int limit = 50,
  }) async {
    final db = await _db;
    if (db == null) return [];
    try {
      final rows = await db.query(
        _table,
        where: 'match_id = ?',
        whereArgs: [matchId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map(MessageModel.fromCacheMap).toList().reversed.toList();
    } catch (e) {
      debugPrint('getCachedMessages error: $e');
      return [];
    }
  }

  /// Lưu/cập nhật danh sách tin nhắn vào SQLite
  Future<void> upsertMessagesToCache(Iterable<MessageModel> messages) async {
    final db = await _db;
    if (db == null) return;
    try {
      final batch = db.batch();
      for (final m in messages) {
        if (m.isPending) continue;
        batch.insert(
          _table,
          m.toCacheMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('upsertMessagesToCache error: $e');
    }
  }

  /// Xóa toàn bộ cache tin nhắn SQLite (khi Logout)
  Future<void> clearCache() async {
    final db = await _db;
    if (db == null) return;
    try {
      await db.delete(_table);
    } catch (e) {
      debugPrint('clearCache error: $e');
    }
  }
}

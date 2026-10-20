import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/notification_item_model.dart';
import '../models/swipe_history_model.dart';
import 'database_adapter.dart';

DatabaseAdapter getDatabaseAdapter() => NativeDatabaseAdapter();

class NativeDatabaseAdapter implements DatabaseAdapter {
  static const String _dbName = 'datingly_local.db';
  static const int _dbVersion = 1;

  static const String tableNotifications = 'notifications_log';
  static const String tableSwipedHistory = 'swiped_history_cache';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  @override
  Future<void> init() async {
    await database;
  }

  Future<Database> _initDatabase() async {
    // Khởi tạo FFI nếu chạy trên nền tảng desktop (Windows, macOS, Linux)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Bảng lưu trữ log thông báo
    await db.execute('''
      CREATE TABLE $tableNotifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notification_id TEXT UNIQUE,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        data TEXT,
        route TEXT,
        created_at INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Bảng lưu trữ cache lịch sử quẹt thẻ
    await db.execute('''
      CREATE TABLE $tableSwipedHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_user_id TEXT NOT NULL,
        target_user_name TEXT,
        target_user_avatar TEXT,
        target_user_age INTEGER,
        target_user_bio TEXT,
        action TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  @override
  Future<int> insertNotification(NotificationItemModel item) async {
    final db = await database;
    try {
      return await db.insert(
        tableNotifications,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('SQLite insertNotification error: $e');
      return -1;
    }
  }

  @override
  Future<List<NotificationItemModel>> getAllNotifications({
    String? typeFilter,
  }) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
      maps = await db.query(
        tableNotifications,
        where: 'type = ?',
        whereArgs: [typeFilter],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        tableNotifications,
        orderBy: 'created_at DESC',
      );
    }

    return maps.map((m) => NotificationItemModel.fromMap(m)).toList();
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableNotifications WHERE is_read = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> markNotificationAsRead(int id) async {
    final db = await database;
    return await db.update(
      tableNotifications,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> markAllNotificationsAsRead() async {
    final db = await database;
    return await db.update(
      tableNotifications,
      {'is_read': 1},
      where: 'is_read = 0',
    );
  }

  @override
  Future<int> deleteNotification(int id) async {
    final db = await database;
    return await db.delete(
      tableNotifications,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> clearAllNotifications() async {
    final db = await database;
    return await db.delete(tableNotifications);
  }

  @override
  Future<int> insertSwipeHistory(SwipeHistoryModel swipe) async {
    final db = await database;
    try {
      return await db.insert(
        tableSwipedHistory,
        swipe.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('SQLite insertSwipeHistory error: $e');
      return -1;
    }
  }

  @override
  Future<List<SwipeHistoryModel>> getRecentSwipeHistory({
    int limit = 100,
    String? actionFilter,
  }) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (actionFilter != null &&
        actionFilter.isNotEmpty &&
        actionFilter != 'all') {
      maps = await db.query(
        tableSwipedHistory,
        where: 'action = ?',
        whereArgs: [actionFilter],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } else {
      maps = await db.query(
        tableSwipedHistory,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    }

    return maps.map((m) => SwipeHistoryModel.fromMap(m)).toList();
  }

  @override
  Future<SwipeHistoryModel?> getLastSwipe() async {
    final db = await database;
    final maps = await db.query(
      tableSwipedHistory,
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SwipeHistoryModel.fromMap(maps.first);
  }

  @override
  Future<int> deleteSwipe(int id) async {
    final db = await database;
    return await db.delete(
      tableSwipedHistory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> deleteSwipeByTargetUserId(String targetUserId) async {
    final db = await database;
    return await db.delete(
      tableSwipedHistory,
      where: 'target_user_id = ?',
      whereArgs: [targetUserId],
    );
  }

  @override
  Future<int> clearAllSwipeHistory() async {
    final db = await database;
    return await db.delete(tableSwipedHistory);
  }

  @override
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete(tableNotifications);
    await db.delete(tableSwipedHistory);
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' show join;
// `sqflite_ffi.dart` re-exports the full sqflite API (Database, databaseFactory,
// OpenDatabaseOptions, …) plus the desktop FFI factory used in [open].
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The on-device SQLite store. FinLens never queries this relationally — the
/// whole store is read into [AppStore] at launch and written back as a snapshot
/// on change — so this class stays deliberately thin: open/create the schema,
/// hand out the [Database] for the persister's transaction, and nothing else.
///
/// One row per domain entity across six tables, plus a flat key/value [metaTable]
/// for the id counter, the tag-migration schema and the budget-history epoch.
/// Sub-structures (budget/goal history, tag-id lists, weekday sets) live in JSON
/// TEXT columns — see `store_mappers.dart` — because nothing ever filters on them.
class LocalDatabase {
  LocalDatabase._(this.db);

  final Database db;

  static const String dbFileName = 'finlens.db';
  static const int schemaVersion = 1;

  static const String accountsTable = 'accounts';
  static const String categoriesTable = 'categories';
  static const String txnsTable = 'txns';
  static const String tagsTable = 'tags';
  static const String goalsTable = 'goals';
  static const String tasksTable = 'tasks';
  static const String metaTable = 'meta';

  /// Entity tables in a dependency-neutral order (there are no FK constraints,
  /// so insertion order is free). Used by the persister to clear + rewrite.
  static const List<String> entityTables = [
    accountsTable,
    categoriesTable,
    txnsTable,
    tagsTable,
    goalsTable,
    tasksTable,
  ];

  /// Opens (creating on first run) the app database. On desktop the plain
  /// `sqflite` plugin has no backend, so the FFI factory is installed first;
  /// on Android/iOS the default native factory is left untouched.
  static Future<LocalDatabase> open() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = join(await databaseFactory.getDatabasesPath(), dbFileName);
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return LocalDatabase._(db);
  }

  Future<List<Map<String, Object?>>> readAll(String table) => db.query(table);

  Future<void> close() => db.close();

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE $accountsTable(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        group_name TEXT NOT NULL,
        currency TEXT NOT NULL,
        starting_balance REAL NOT NULL,
        credit_limit REAL,
        statement_day INTEGER,
        payment_due INTEGER,
        hidden INTEGER NOT NULL,
        archived INTEGER NOT NULL,
        count_as_spendable INTEGER NOT NULL,
        icon_code_point INTEGER,
        icon_font_family TEXT,
        icon_font_package TEXT,
        icon_match_text_direction INTEGER,
        opened_on INTEGER,
        opening_date INTEGER
      )''');
    batch.execute('''
      CREATE TABLE $categoriesTable(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type_name TEXT NOT NULL,
        icon_code_point INTEGER,
        icon_font_family TEXT,
        icon_font_package TEXT,
        icon_match_text_direction INTEGER,
        color_argb INTEGER NOT NULL,
        monthly_budget REAL,
        budget_rollover INTEGER NOT NULL,
        warn_threshold REAL NOT NULL,
        rollover_amount REAL NOT NULL,
        archived INTEGER NOT NULL,
        removed_on INTEGER,
        budget_history TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE $txnsTable(
        id TEXT PRIMARY KEY,
        type_name TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        from_ref TEXT NOT NULL,
        to_ref TEXT NOT NULL,
        date INTEGER NOT NULL,
        exchange_rate REAL,
        to_amount REAL,
        fee REAL,
        fee_from_source INTEGER NOT NULL,
        tag_ids TEXT NOT NULL,
        note TEXT NOT NULL,
        edited_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        goal_id TEXT,
        split_group_id TEXT,
        recurrence_task_id TEXT
      )''');
    batch.execute('''
      CREATE TABLE $tagsTable(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        archived INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE $goalsTable(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        source_kind TEXT NOT NULL,
        source_id TEXT NOT NULL,
        target_amount REAL NOT NULL,
        target_date INTEGER,
        ends_when_reached INTEGER NOT NULL,
        status_name TEXT NOT NULL,
        note TEXT NOT NULL,
        completed_at INTEGER,
        stopped_at INTEGER,
        created_at INTEGER NOT NULL,
        history TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE $tasksTable(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        linked_account_id TEXT NOT NULL,
        expected_amount REAL NOT NULL,
        due_date INTEGER NOT NULL,
        icon_code_point INTEGER,
        icon_font_family TEXT,
        icon_font_package TEXT,
        icon_match_text_direction INTEGER,
        category_id TEXT,
        pay_to_account_id TEXT,
        note TEXT,
        status_changed_at INTEGER,
        repeats_name TEXT NOT NULL,
        weekdays TEXT NOT NULL,
        days_of_month TEXT NOT NULL,
        skipped_dates TEXT NOT NULL,
        priority_name TEXT NOT NULL,
        reminder_days_before INTEGER,
        reminder_time_minutes INTEGER,
        status_name TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE $metaTable(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    await batch.commit(noResult: true);
  }

  /// No migrations yet (schema v1). Future schema bumps add cases here.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daily_english.db');
    return openDatabase(path, version: 14, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        translation_2 TEXT,
        translation_3 TEXT,
        meaning TEXT,
        meaning_pt TEXT,
        example_1 TEXT,
        example_translation_1 TEXT,
        example_2 TEXT,
        example_translation_2 TEXT,
        example_3 TEXT,
        example_translation_3 TEXT,
        synonyms TEXT,
        opposite TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        status TEXT DEFAULT 'learning',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_review_at INTEGER,
        ease_factor REAL DEFAULT 2.5,
        sr_repetitions INTEGER DEFAULT 0,
        sr_interval INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE diary_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        corrected_content TEXT,
        comments TEXT,
        mood TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE phrases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phrase TEXT NOT NULL,
        translation TEXT NOT NULL,
        meaning_en TEXT,
        meaning_pt TEXT,
        example_1 TEXT,
        example_translation_1 TEXT,
        example_2 TEXT,
        example_translation_2 TEXT,
        example_3 TEXT,
        example_translation_3 TEXT,
        difficulty INTEGER DEFAULT 1,
        status TEXT DEFAULT 'learning',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_review_at INTEGER,
        ease_factor REAL DEFAULT 2.5,
        sr_repetitions INTEGER DEFAULT 0,
        sr_interval INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    final defaultCategories = [
      'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
      'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
      'Environmental Police', 'Immigration', 'Conversation', 'Study',
    ];
    final now = DateTime.now().toIso8601String();
    for (final name in defaultCategories) {
      await db.insert('categories', {'name': name, 'created_at': now});
    }

    await db.execute('''
      CREATE TABLE phrasal_verbs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        base_verb TEXT NOT NULL,
        particle TEXT NOT NULL,
        meaning TEXT NOT NULL,
        meaning_pt TEXT,
        meaning_en TEXT,
        example_1 TEXT,
        example_translation_1 TEXT,
        example_2 TEXT,
        example_translation_2 TEXT,
        example_3 TEXT,
        example_translation_3 TEXT,
        difficulty INTEGER DEFAULT 1,
        status TEXT DEFAULT 'learning',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_review_at INTEGER,
        ease_factor REAL DEFAULT 2.5,
        sr_repetitions INTEGER DEFAULT 0,
        sr_interval INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE player_stats (
        id INTEGER PRIMARY KEY,
        xp INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        streak INTEGER DEFAULT 0,
        shields INTEGER DEFAULT 0,
        last_activity_date TEXT,
        streak_at_risk INTEGER DEFAULT 0,
        games_played_today TEXT DEFAULT ''
      )
    ''');
    await db.insert('player_stats', {
      'id': 1, 'xp': 0, 'level': 1, 'streak': 0, 'shields': 0,
      'streak_at_risk': 0, 'games_played_today': '',
    });

    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        activity TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE words ADD COLUMN translation_2 TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN translation_3 TEXT');
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE words ADD COLUMN meaning_pt TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN example_translation_1 TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN example_translation_2 TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN example_translation_3 TEXT'); } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS diary_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          mood TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE diary_entries ADD COLUMN corrected_content TEXT'); } catch (_) {}
    }
    if (oldVersion < 8) {
      try { await db.execute('ALTER TABLE words ADD COLUMN next_review_at INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN ease_factor REAL DEFAULT 2.5'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN sr_repetitions INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN sr_interval INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS phrases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phrase TEXT NOT NULL,
          translation TEXT NOT NULL,
          meaning_en TEXT,
          meaning_pt TEXT,
          example_1 TEXT,
          example_translation_1 TEXT,
          example_2 TEXT,
          example_translation_2 TEXT,
          example_3 TEXT,
          example_translation_3 TEXT,
          difficulty INTEGER DEFAULT 1,
          status TEXT DEFAULT 'learning',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');
      final defaultCategories = [
        'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
        'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
        'Environmental Police', 'Immigration', 'Conversation', 'Study',
      ];
      final now = DateTime.now().toIso8601String();
      for (final name in defaultCategories) {
        try {
          await db.insert('categories', {'name': name, 'created_at': now});
        } catch (_) {}
      }
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS phrasal_verbs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          base_verb TEXT NOT NULL,
          particle TEXT NOT NULL,
          meaning TEXT NOT NULL,
          meaning_pt TEXT,
          meaning_en TEXT,
          example_1 TEXT,
          example_translation_1 TEXT,
          example_2 TEXT,
          example_translation_2 TEXT,
          example_3 TEXT,
          example_translation_3 TEXT,
          difficulty INTEGER DEFAULT 1,
          status TEXT DEFAULT 'learning',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 11) {
      try { await db.execute('ALTER TABLE phrasal_verbs ADD COLUMN next_review_at INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrasal_verbs ADD COLUMN ease_factor REAL DEFAULT 2.5'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrasal_verbs ADD COLUMN sr_repetitions INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrasal_verbs ADD COLUMN sr_interval INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrases ADD COLUMN next_review_at INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrases ADD COLUMN ease_factor REAL DEFAULT 2.5'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrases ADD COLUMN sr_repetitions INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE phrases ADD COLUMN sr_interval INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS player_stats (
          id INTEGER PRIMARY KEY,
          xp INTEGER DEFAULT 0,
          level INTEGER DEFAULT 1,
          streak INTEGER DEFAULT 0,
          shields INTEGER DEFAULT 0,
          last_activity_date TEXT,
          streak_at_risk INTEGER DEFAULT 0,
          games_played_today TEXT DEFAULT ''
        )
      ''');
      try {
        await db.insert('player_stats', {
          'id': 1, 'xp': 0, 'level': 1, 'streak': 0, 'shields': 0,
          'streak_at_risk': 0, 'games_played_today': '',
        });
      } catch (_) {}
    }
    if (oldVersion < 13) {
      try { await db.execute('ALTER TABLE diary_entries ADD COLUMN comments TEXT'); } catch (_) {}
    }
    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          duration_minutes INTEGER NOT NULL,
          date TEXT NOT NULL,
          activity TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }
}

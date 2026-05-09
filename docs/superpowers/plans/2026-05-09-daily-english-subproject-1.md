# Daily English Sub-projeto 1: Fundação + Dicionário — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Flutter app from scratch with Clean Architecture, SQLite, and full CRUD for English words.

**Architecture:** Screen → Riverpod Provider → Repository → SQLite. Each layer only knows the layer below it. AppDatabase is a lazy-initialized singleton exposed via Riverpod.

**Tech Stack:** Flutter/Dart, flutter_riverpod ^2.5.1, sqflite ^2.3.2, go_router ^14.2.7, google_fonts ^6.1.0, sqflite_common_ffi ^2.3.3 (tests)

---

## File Map

| File | Responsibility |
|---|---|
| `pubspec.yaml` | Dependencies |
| `lib/main.dart` | ProviderScope + runApp |
| `lib/app.dart` | MaterialApp.router + theme |
| `lib/core/theme/app_theme.dart` | Colors, fonts, component styles |
| `lib/core/database/app_database.dart` | SQLite init, table creation |
| `lib/core/router/app_router.dart` | GoRouter with all 5 routes |
| `lib/models/word.dart` | Word class, fromMap, toMap, copyWith |
| `lib/repositories/word_repository.dart` | CRUD + search + filter |
| `lib/providers/word_provider.dart` | databaseProvider, wordRepositoryProvider, wordListProvider, wordDetailProvider |
| `lib/screens/home/home_screen.dart` | Dashboard with stats and navigation |
| `lib/screens/words/words_screen.dart` | List + search + filter chips |
| `lib/screens/words/word_form_screen.dart` | Create/edit form |
| `lib/screens/words/word_detail_screen.dart` | Detail view + status selector + delete |
| `test/models/word_test.dart` | Unit tests for Word model |
| `test/repositories/word_repository_test.dart` | Unit tests for WordRepository |

---

## Task 1: Initialize Flutter Project

**Files:**
- Create: `pubspec.yaml` (modify after flutter create)

- [ ] **Step 1: Run flutter create in the project directory**

Open a terminal in `c:\Programacao\05 - Projects\daily_english` and run:

```bash
flutter create . --project-name daily_english --org com.dailyenglish
```

Expected output ends with: `All done! Your project is created.`

- [ ] **Step 2: Replace pubspec.yaml content**

Replace the entire `pubspec.yaml` with:

```yaml
name: daily_english
description: A personal English learning dictionary.
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  sqflite: ^2.3.2
  path: ^1.9.0
  go_router: ^14.2.7
  google_fonts: ^6.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  sqflite_common_ffi: ^2.3.3

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Install dependencies**

```bash
flutter pub get
```

Expected: `Got dependencies!`

- [ ] **Step 4: Delete generated boilerplate**

Delete `lib/main.dart` content (will be replaced in Task 9).
Delete `test/widget_test.dart`.

- [ ] **Step 5: Verify Flutter is working**

```bash
flutter analyze
```

Expected: No errors (only the empty lib/ may warn — that's fine for now).

- [ ] **Step 6: Commit**

```bash
git init
git add pubspec.yaml pubspec.lock
git commit -m "feat: initialize Flutter project with dependencies"
```

---

## Task 2: Word Model

**Files:**
- Create: `lib/models/word.dart`
- Create: `test/models/word_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/models/word_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_english/models/word.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  final sampleMap = {
    'id': 1,
    'word': 'improve',
    'translation': 'melhorar',
    'meaning': 'To make something better',
    'example_1': 'I want to improve my English.',
    'example_2': null,
    'example_3': null,
    'synonyms': 'enhance, develop',
    'opposite': 'worsen',
    'category': 'Verbs',
    'difficulty': 2,
    'status': 'learning',
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };

  group('Word.fromMap', () {
    test('creates Word with all fields', () {
      final word = Word.fromMap(sampleMap);
      expect(word.id, 1);
      expect(word.word, 'improve');
      expect(word.translation, 'melhorar');
      expect(word.meaning, 'To make something better');
      expect(word.example1, 'I want to improve my English.');
      expect(word.example2, null);
      expect(word.synonyms, 'enhance, develop');
      expect(word.opposite, 'worsen');
      expect(word.category, 'Verbs');
      expect(word.difficulty, 2);
      expect(word.status, 'learning');
      expect(word.createdAt, now);
    });

    test('uses defaults for missing optional fields', () {
      final minimal = {
        'id': 1,
        'word': 'run',
        'translation': 'correr',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final word = Word.fromMap(minimal);
      expect(word.difficulty, 1);
      expect(word.status, 'learning');
      expect(word.meaning, null);
      expect(word.category, null);
    });
  });

  group('Word.toMap', () {
    test('produces correct map with id', () {
      final word = Word.fromMap(sampleMap);
      final map = word.toMap();
      expect(map['id'], 1);
      expect(map['word'], 'improve');
      expect(map['translation'], 'melhorar');
      expect(map['difficulty'], 2);
      expect(map['status'], 'learning');
      expect(map['created_at'], now.toIso8601String());
    });

    test('omits id when null', () {
      final word = Word(
        word: 'run',
        translation: 'correr',
        difficulty: 1,
        status: 'learning',
        createdAt: now,
        updatedAt: now,
      );
      final map = word.toMap();
      expect(map.containsKey('id'), false);
    });
  });

  group('Word.copyWith', () {
    test('updates only specified fields', () {
      final word = Word.fromMap(sampleMap);
      final updated = word.copyWith(status: 'learned');
      expect(updated.status, 'learned');
      expect(updated.word, 'improve');
      expect(updated.id, 1);
    });

    test('updates updatedAt independently', () {
      final word = Word.fromMap(sampleMap);
      final later = DateTime(2026, 6, 1);
      final updated = word.copyWith(updatedAt: later);
      expect(updated.updatedAt, later);
      expect(updated.createdAt, now);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/models/word_test.dart
```

Expected: FAIL — `Target file "lib/models/word.dart" not found.`

- [ ] **Step 3: Create lib/models/word.dart**

```dart
class Word {
  final int? id;
  final String word;
  final String translation;
  final String? meaning;
  final String? example1;
  final String? example2;
  final String? example3;
  final String? synonyms;
  final String? opposite;
  final String? category;
  final int difficulty;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Word({
    this.id,
    required this.word,
    required this.translation,
    this.meaning,
    this.example1,
    this.example2,
    this.example3,
    this.synonyms,
    this.opposite,
    this.category,
    this.difficulty = 1,
    this.status = 'learning',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String,
      meaning: map['meaning'] as String?,
      example1: map['example_1'] as String?,
      example2: map['example_2'] as String?,
      example3: map['example_3'] as String?,
      synonyms: map['synonyms'] as String?,
      opposite: map['opposite'] as String?,
      category: map['category'] as String?,
      difficulty: map['difficulty'] as int? ?? 1,
      status: map['status'] as String? ?? 'learning',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'translation': translation,
      'meaning': meaning,
      'example_1': example1,
      'example_2': example2,
      'example_3': example3,
      'synonyms': synonyms,
      'opposite': opposite,
      'category': category,
      'difficulty': difficulty,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? meaning,
    String? example1,
    String? example2,
    String? example3,
    String? synonyms,
    String? opposite,
    String? category,
    int? difficulty,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      meaning: meaning ?? this.meaning,
      example1: example1 ?? this.example1,
      example2: example2 ?? this.example2,
      example3: example3 ?? this.example3,
      synonyms: synonyms ?? this.synonyms,
      opposite: opposite ?? this.opposite,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/models/word_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/word.dart test/models/word_test.dart
git commit -m "feat: add Word model with fromMap, toMap, copyWith"
```

---

## Task 3: AppDatabase

**Files:**
- Create: `lib/core/database/app_database.dart`

- [ ] **Step 1: Create lib/core/database/app_database.dart**

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daily_english.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        meaning TEXT,
        example_1 TEXT,
        example_2 TEXT,
        example_3 TEXT,
        synonyms TEXT,
        opposite TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        status TEXT DEFAULT 'learning',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/database/app_database.dart
git commit -m "feat: add AppDatabase with SQLite init and words table"
```

---

## Task 4: WordRepository

**Files:**
- Create: `lib/repositories/word_repository.dart`
- Create: `test/repositories/word_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/repositories/word_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_english/models/word.dart';
import 'package:daily_english/repositories/word_repository.dart';

void main() {
  late Database db;
  late WordRepository repo;
  final now = DateTime(2026, 1, 1);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word TEXT NOT NULL,
              translation TEXT NOT NULL,
              meaning TEXT,
              example_1 TEXT,
              example_2 TEXT,
              example_3 TEXT,
              synonyms TEXT,
              opposite TEXT,
              category TEXT,
              difficulty INTEGER DEFAULT 1,
              status TEXT DEFAULT 'learning',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    repo = WordRepository(Future.value(db));
  });

  tearDown(() => db.close());

  Word makeWord({
    String word = 'improve',
    String translation = 'melhorar',
    String? category,
    String status = 'learning',
  }) {
    return Word(
      word: word,
      translation: translation,
      category: category,
      status: status,
      difficulty: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('insert and getAll returns inserted word', () async {
    await repo.insert(makeWord());
    final words = await repo.getAll();
    expect(words.length, 1);
    expect(words.first.word, 'improve');
    expect(words.first.id, isNotNull);
  });

  test('getById returns correct word', () async {
    final id = await repo.insert(makeWord());
    final word = await repo.getById(id);
    expect(word?.word, 'improve');
    expect(word?.id, id);
  });

  test('getById returns null for missing id', () async {
    final word = await repo.getById(999);
    expect(word, null);
  });

  test('search finds by word prefix', () async {
    await repo.insert(makeWord(word: 'improve', translation: 'melhorar'));
    await repo.insert(makeWord(word: 'run', translation: 'correr'));
    final results = await repo.search('impr');
    expect(results.length, 1);
    expect(results.first.word, 'improve');
  });

  test('search finds by translation', () async {
    await repo.insert(makeWord(word: 'improve', translation: 'melhorar'));
    await repo.insert(makeWord(word: 'run', translation: 'correr'));
    final results = await repo.search('melh');
    expect(results.length, 1);
    expect(results.first.word, 'improve');
  });

  test('filterByCategory returns only matching words', () async {
    await repo.insert(makeWord(word: 'work', translation: 'trabalho', category: 'Work'));
    await repo.insert(makeWord(word: 'run', translation: 'correr'));
    final results = await repo.filterByCategory('Work');
    expect(results.length, 1);
    expect(results.first.word, 'work');
  });

  test('filterByStatus returns only matching words', () async {
    await repo.insert(makeWord(word: 'improve', status: 'learned'));
    await repo.insert(makeWord(word: 'run', status: 'learning'));
    final results = await repo.filterByStatus('learned');
    expect(results.length, 1);
    expect(results.first.word, 'improve');
  });

  test('update changes word fields', () async {
    final id = await repo.insert(makeWord());
    final inserted = (await repo.getById(id))!;
    await repo.update(inserted.copyWith(status: 'learned'));
    final fetched = await repo.getById(id);
    expect(fetched?.status, 'learned');
  });

  test('delete removes word', () async {
    final id = await repo.insert(makeWord());
    await repo.delete(id);
    final word = await repo.getById(id);
    expect(word, null);
  });

  test('getAll returns multiple words ordered by created_at DESC', () async {
    await repo.insert(makeWord(word: 'apple'));
    await repo.insert(makeWord(word: 'banana'));
    final words = await repo.getAll();
    expect(words.length, 2);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/repositories/word_repository_test.dart
```

Expected: FAIL — `WordRepository` not found.

- [ ] **Step 3: Create lib/repositories/word_repository.dart**

```dart
import 'package:sqflite/sqflite.dart';
import '../models/word.dart';

class WordRepository {
  final Future<Database> _futureDb;

  const WordRepository(this._futureDb);

  Future<List<Word>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('words', orderBy: 'created_at DESC');
    return maps.map(Word.fromMap).toList();
  }

  Future<Word?> getById(int id) async {
    final db = await _futureDb;
    final maps = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  Future<List<Word>> search(String query) async {
    final db = await _futureDb;
    final pattern = '%$query%';
    final maps = await db.query(
      'words',
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> filterByCategory(String category) async {
    final db = await _futureDb;
    final maps = await db.query(
      'words',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> filterByStatus(String status) async {
    final db = await _futureDb;
    final maps = await db.query(
      'words',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<int> insert(Word word) async {
    final db = await _futureDb;
    return db.insert('words', word.toMap());
  }

  Future<void> update(Word word) async {
    final db = await _futureDb;
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/repositories/word_repository_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/word_repository.dart test/repositories/word_repository_test.dart
git commit -m "feat: add WordRepository with CRUD, search, and filter"
```

---

## Task 5: Riverpod Providers

**Files:**
- Create: `lib/providers/word_provider.dart`

- [ ] **Step 1: Create lib/providers/word_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return WordRepository(appDb.database);
});

class WordListNotifier extends AsyncNotifier<List<Word>> {
  String _searchQuery = '';
  String? _categoryFilter;
  String? _statusFilter;

  @override
  Future<List<Word>> build() => _fetch();

  Future<List<Word>> _fetch() {
    final repo = ref.read(wordRepositoryProvider);
    if (_searchQuery.isNotEmpty) return repo.search(_searchQuery);
    if (_categoryFilter != null) return repo.filterByCategory(_categoryFilter!);
    if (_statusFilter != null) return repo.filterByStatus(_statusFilter!);
    return repo.getAll();
  }

  Future<void> addWord(Word word) async {
    await ref.read(wordRepositoryProvider).insert(word);
    ref.invalidateSelf();
  }

  Future<void> updateWord(Word word) async {
    await ref.read(wordRepositoryProvider).update(word);
    ref.invalidateSelf();
  }

  Future<void> deleteWord(int id) async {
    await ref.read(wordRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _categoryFilter = null;
    _statusFilter = null;
    ref.invalidateSelf();
  }

  void setFilter({String? category, String? status}) {
    _searchQuery = '';
    _categoryFilter = category;
    _statusFilter = status;
    ref.invalidateSelf();
  }
}

final wordListProvider =
    AsyncNotifierProvider<WordListNotifier, List<Word>>(WordListNotifier.new);

final wordDetailProvider = FutureProvider.family<Word?, int>((ref, id) {
  return ref.watch(wordRepositoryProvider).getById(id);
});
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/providers/word_provider.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/word_provider.dart
git commit -m "feat: add Riverpod providers for database, repository, and word list"
```

---

## Task 6: Theme and Router

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/router/app_router.dart`

- [ ] **Step 1: Create lib/core/theme/app_theme.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF58CC02);
  static const Color secondary = Color(0xFF1CB0F6);
  static const Color tertiary = Color(0xFFCE82FF);
  static const Color error = Color(0xFFFF4B4B);
  static const Color warning = Color(0xFFFF9600);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F7F7);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF777777);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        error: error,
        surface: surface,
        onPrimary: onPrimary,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: primary.withOpacity(0.15),
        labelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
```

- [ ] **Step 2: Create lib/core/router/app_router.dart**

```dart
import 'package:go_router/go_router.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/words/words_screen.dart';
import '../../screens/words/word_form_screen.dart';
import '../../screens/words/word_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/words',
      builder: (context, state) => const WordsScreen(),
    ),
    GoRoute(
      path: '/words/new',
      builder: (context, state) => const WordFormScreen(),
    ),
    GoRoute(
      path: '/words/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WordFormScreen(wordId: id);
      },
    ),
    GoRoute(
      path: '/words/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WordDetailScreen(wordId: id);
      },
    ),
  ],
);
```

> Note: `/words/new` must appear before `/words/:id` to prevent `new` being parsed as an id.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/app_theme.dart lib/core/router/app_router.dart
git commit -m "feat: add app theme (Duolingo-style) and GoRouter routes"
```

---

## Task 7: main.dart and app.dart

**Files:**
- Create: `lib/main.dart`
- Create: `lib/app.dart`

- [ ] **Step 1: Create lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: DailyEnglishApp()));
}
```

- [ ] **Step 2: Create lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class DailyEnglishApp extends StatelessWidget {
  const DailyEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Daily English',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 3: Verify the app compiles**

```bash
flutter analyze
```

Expected: No issues (screens don't exist yet — that will cause errors, fix in next tasks).

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: add main entry point and MaterialApp.router setup"
```

---

## Task 8: HomeScreen

**Files:**
- Create: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Create lib/screens/home/home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(wordListProvider);
    final wordCount = wordsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Daily English',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                'Your personal English dictionary',
                style: GoogleFonts.nunito(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              _StatsCard(wordCount: wordCount),
              const SizedBox(height: 24),
              _MenuButton(
                label: 'My Words',
                icon: Icons.menu_book_rounded,
                color: AppTheme.secondary,
                onTap: () => context.go('/words'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Add Word',
                icon: Icons.add_circle_outline_rounded,
                color: AppTheme.primary,
                onTap: () => context.go('/words/new'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Phrasal Verbs',
                icon: Icons.auto_stories_rounded,
                color: AppTheme.tertiary,
                onTap: null,
                comingSoon: true,
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Flashcards',
                icon: Icons.style_rounded,
                color: AppTheme.warning,
                onTap: null,
                comingSoon: true,
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'My Diary',
                icon: Icons.edit_note_rounded,
                color: AppTheme.secondary,
                onTap: null,
                comingSoon: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int wordCount;
  const _StatsCard({required this.wordCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.secondary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$wordCount',
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  'words in your dictionary',
                  style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool comingSoon;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: comingSoon ? 0.45 : 1.0,
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: color, size: 28),
          title: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          trailing: comingSoon
              ? Text(
                  'Em breve',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textSecondary),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: add HomeScreen with word count stats and navigation menu"
```

---

## Task 9: WordsScreen

**Files:**
- Create: `lib/screens/words/words_screen.dart`

- [ ] **Step 1: Create lib/screens/words/words_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../models/word.dart';
import '../../core/theme/app_theme.dart';

const _wordCategories = [
  'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
  'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
  'Environmental Police', 'Immigration', 'Conversation',
];

const _wordStatuses = ['learning', 'learned', 'difficult'];

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(wordListProvider.notifier).setSearch(query);
    setState(() {
      _selectedCategory = null;
      _selectedStatus = null;
    });
  }

  void _onCategoryTap(String category) {
    final next = _selectedCategory == category ? null : category;
    setState(() {
      _selectedCategory = next;
      _selectedStatus = null;
      _searchController.clear();
    });
    ref.read(wordListProvider.notifier).setFilter(category: next);
  }

  void _onStatusTap(String status) {
    final next = _selectedStatus == status ? null : status;
    setState(() {
      _selectedStatus = next;
      _selectedCategory = null;
      _searchController.clear();
    });
    ref.read(wordListProvider.notifier).setFilter(status: next);
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(wordListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Words'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/words/new'),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search words...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._wordStatuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_statusLabel(s)),
                    selected: _selectedStatus == s,
                    onSelected: (_) => _onStatusTap(s),
                    selectedColor: _statusColor(s).withOpacity(0.2),
                  ),
                )),
                ..._wordCategories.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c),
                    selected: _selectedCategory == c,
                    onSelected: (_) => _onCategoryTap(c),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: wordsAsync.when(
              data: (words) => words.isEmpty
                  ? _EmptyState(onAdd: () => context.go('/words/new'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: words.length,
                      itemBuilder: (_, i) => _WordCard(word: words[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) =>
      s == 'learning' ? 'Learning' : s == 'learned' ? 'Learned' : 'Difficult';

  Color _statusColor(String s) =>
      s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;
}

class _WordCard extends StatelessWidget {
  final Word word;
  const _WordCard({required this.word});

  Color _statusColor(String s) =>
      s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(word.status);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          word.word,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          word.translation,
          style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            word.status[0].toUpperCase() + word.status.substring(1),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        onTap: () => context.go('/words/${word.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No words yet.',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first word!',
            style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Word'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/words/words_screen.dart
git commit -m "feat: add WordsScreen with search, filter chips, and word list"
```

---

## Task 10: WordFormScreen

**Files:**
- Create: `lib/screens/words/word_form_screen.dart`

- [ ] **Step 1: Create lib/screens/words/word_form_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/word.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';

const _wordCategories = [
  'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
  'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
  'Environmental Police', 'Immigration', 'Conversation',
];

class WordFormScreen extends ConsumerStatefulWidget {
  final int? wordId;
  const WordFormScreen({super.key, this.wordId});

  @override
  ConsumerState<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends ConsumerState<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  late final TextEditingController _wordCtrl;
  late final TextEditingController _translationCtrl;
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _example1Ctrl;
  late final TextEditingController _example2Ctrl;
  late final TextEditingController _example3Ctrl;
  late final TextEditingController _synonymsCtrl;
  late final TextEditingController _oppositeCtrl;

  String? _selectedCategory;
  int _difficulty = 1;
  String _status = 'learning';
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.wordId != null;
    _wordCtrl = TextEditingController();
    _translationCtrl = TextEditingController();
    _meaningCtrl = TextEditingController();
    _example1Ctrl = TextEditingController();
    _example2Ctrl = TextEditingController();
    _example3Ctrl = TextEditingController();
    _synonymsCtrl = TextEditingController();
    _oppositeCtrl = TextEditingController();

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWord());
    }
  }

  Future<void> _loadWord() async {
    final word = await ref.read(wordDetailProvider(widget.wordId!).future);
    if (word == null || !mounted) return;
    setState(() {
      _wordCtrl.text = word.word;
      _translationCtrl.text = word.translation;
      _meaningCtrl.text = word.meaning ?? '';
      _example1Ctrl.text = word.example1 ?? '';
      _example2Ctrl.text = word.example2 ?? '';
      _example3Ctrl.text = word.example3 ?? '';
      _synonymsCtrl.text = word.synonyms ?? '';
      _oppositeCtrl.text = word.opposite ?? '';
      _selectedCategory = word.category;
      _difficulty = word.difficulty;
      _status = word.status;
      _originalCreatedAt = word.createdAt;
    });
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _translationCtrl.dispose();
    _meaningCtrl.dispose();
    _example1Ctrl.dispose();
    _example2Ctrl.dispose();
    _example3Ctrl.dispose();
    _synonymsCtrl.dispose();
    _oppositeCtrl.dispose();
    super.dispose();
  }

  String? _notEmpty(String? v) =>
      v == null || v.trim().isEmpty ? 'Campo obrigatório' : null;

  String? _nullable(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();

    final word = Word(
      id: widget.wordId,
      word: _wordCtrl.text.trim(),
      translation: _translationCtrl.text.trim(),
      meaning: _nullable(_meaningCtrl.text),
      example1: _nullable(_example1Ctrl.text),
      example2: _nullable(_example2Ctrl.text),
      example3: _nullable(_example3Ctrl.text),
      synonyms: _nullable(_synonymsCtrl.text),
      opposite: _nullable(_oppositeCtrl.text),
      category: _selectedCategory,
      difficulty: _difficulty,
      status: _status,
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
    );

    if (_isEditing) {
      await ref.read(wordListProvider.notifier).updateWord(word);
    } else {
      await ref.read(wordListProvider.notifier).addWord(word);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isEditing ? 'Palavra atualizada com sucesso!' : 'Palavra salva com sucesso!'),
      backgroundColor: AppTheme.primary,
    ));
    context.go('/words');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Word' : 'Add Word'),
        leading: BackButton(onPressed: () => context.go('/words')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('REQUIRED'),
            _Field(controller: _wordCtrl, label: 'Word', validator: _notEmpty),
            const SizedBox(height: 12),
            _Field(controller: _translationCtrl, label: 'Translation', validator: _notEmpty),
            const SizedBox(height: 20),
            _SectionLabel('DETAILS'),
            _Field(controller: _meaningCtrl, label: 'Meaning'),
            const SizedBox(height: 12),
            _Field(controller: _example1Ctrl, label: 'Example 1'),
            const SizedBox(height: 12),
            _Field(controller: _example2Ctrl, label: 'Example 2'),
            const SizedBox(height: 12),
            _Field(controller: _example3Ctrl, label: 'Example 3'),
            const SizedBox(height: 12),
            _Field(controller: _synonymsCtrl, label: 'Synonyms'),
            const SizedBox(height: 12),
            _Field(controller: _oppositeCtrl, label: 'Opposite'),
            const SizedBox(height: 20),
            _SectionLabel('CATEGORY'),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(hintText: 'Select a category'),
              items: _wordCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 20),
            _SectionLabel('DIFFICULTY'),
            Row(
              children: [
                _DiffChip(label: 'Easy', value: 1, selected: _difficulty == 1,
                    color: AppTheme.primary, onTap: () => setState(() => _difficulty = 1)),
                const SizedBox(width: 8),
                _DiffChip(label: 'Medium', value: 2, selected: _difficulty == 2,
                    color: AppTheme.warning, onTap: () => setState(() => _difficulty = 2)),
                const SizedBox(width: 8),
                _DiffChip(label: 'Hard', value: 3, selected: _difficulty == 3,
                    color: AppTheme.error, onTap: () => setState(() => _difficulty = 3)),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _Field({required this.controller, required this.label, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DiffChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/words/word_form_screen.dart
git commit -m "feat: add WordFormScreen for creating and editing words"
```

---

## Task 11: WordDetailScreen

**Files:**
- Create: `lib/screens/words/word_detail_screen.dart`

- [ ] **Step 1: Create lib/screens/words/word_detail_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';

class WordDetailScreen extends ConsumerWidget {
  final int wordId;
  const WordDetailScreen({super.key, required this.wordId});

  Color _statusColor(String s) =>
      s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;

  Color _diffColor(int d) =>
      d == 1 ? AppTheme.primary : d == 2 ? AppTheme.warning : AppTheme.error;

  String _diffLabel(int d) => d == 1 ? 'Easy' : d == 2 ? 'Medium' : 'Hard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordAsync = ref.watch(wordDetailProvider(wordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Details'),
        leading: BackButton(onPressed: () => context.go('/words')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.go('/words/$wordId/edit'),
          ),
        ],
      ),
      body: wordAsync.when(
        data: (word) {
          if (word == null) {
            return const Center(child: Text('Palavra não encontrada.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              word.word,
                              style: GoogleFonts.nunito(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(word.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              word.status[0].toUpperCase() + word.status.substring(1),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(word.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        word.translation,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (word.meaning != null) ...[
                _InfoCard(title: 'Meaning', child: Text(word.meaning!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              if ([word.example1, word.example2, word.example3].any((e) => e != null)) ...[
                _InfoCard(
                  title: 'Examples',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [word.example1, word.example2, word.example3]
                        .whereType<String>()
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e.key + 1}. ',
                                      style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.secondary)),
                                  Expanded(child: Text(e.value, style: _bodyStyle)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (word.synonyms != null) ...[
                _InfoCard(title: 'Synonyms', child: Text(word.synonyms!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              if (word.opposite != null) ...[
                _InfoCard(title: 'Opposite', child: Text(word.opposite!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              if (word.category != null) ...[
                _InfoCard(title: 'Category', child: Text(word.category!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              _InfoCard(
                title: 'Difficulty',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _diffColor(word.difficulty).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _diffLabel(word.difficulty),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _diffColor(word.difficulty),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Status',
                child: Row(
                  children: ['learning', 'learned', 'difficult'].map((s) {
                    final color = _statusColor(s);
                    final selected = word.status == s;
                    final label = s[0].toUpperCase() + s.substring(1);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () async {
                          if (selected) return;
                          final updated = word.copyWith(
                            status: s,
                            updatedAt: DateTime.now(),
                          );
                          await ref.read(wordListProvider.notifier).updateWord(updated);
                          ref.invalidate(wordDetailProvider(wordId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Status atualizado!')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? color : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  TextStyle get _bodyStyle =>
      GoogleFonts.nunito(fontSize: 15, color: AppTheme.textPrimary);

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: const Text('Tem certeza que deseja remover esta palavra?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(wordListProvider.notifier).deleteWord(wordId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Palavra removida.')),
                );
                context.go('/words');
              }
            },
            child: const Text('Remover', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/words/word_detail_screen.dart
git commit -m "feat: add WordDetailScreen with status selector and delete confirmation"
```

---

## Task 12: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
flutter test
```

Expected: All tests PASS.

- [ ] **Step 2: Run static analysis**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 3: Run the app on a device or emulator**

```bash
flutter run
```

Verify manually:
- [ ] HomeScreen loads and shows word count (0)
- [ ] "Add Word" navigates to WordFormScreen
- [ ] Save a word — "Palavra salva com sucesso!" appears
- [ ] Word appears in WordsScreen list
- [ ] Search filters words in real time
- [ ] Tap word opens WordDetailScreen
- [ ] Edit word saves changes
- [ ] Delete word with confirmation removes it
- [ ] Status change updates immediately
- [ ] Close and reopen app — words persist

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat: complete Sub-projeto 1 — foundation and words dictionary"
```

---

## Checklist Against Spec

| Requirement | Task |
|---|---|
| Projeto Flutter executa sem erros Android/iOS | Task 1 |
| Banco SQLite cria tabela words | Task 3 |
| CRUD completo de palavras | Tasks 4–11 |
| Busca por palavra e tradução em tempo real | Task 9 |
| Filtros por categoria e status | Task 9 |
| Status alterável na tela de detalhes | Task 11 |
| Tema visual aplicado consistentemente | Task 6 |
| Navegação entre todas as telas | Task 6, 7 |
| App não perde dados ao fechar | Task 3, 4 |

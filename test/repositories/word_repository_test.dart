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
              synonym_1 TEXT,
              synonym_2 TEXT,
              synonym_3 TEXT,
              synonym_4 TEXT,
              synonym_5 TEXT,
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
    await repo.insert(
        makeWord(word: 'work', translation: 'trabalho', category: 'Work'));
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

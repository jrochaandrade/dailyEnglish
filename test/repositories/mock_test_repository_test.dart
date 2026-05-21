import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_english/models/mock_test.dart';
import 'package:daily_english/repositories/mock_test_repository.dart';

void main() {
  late Database db;
  late MockTestRepository repo;

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
            CREATE TABLE mock_tests (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              listening_score REAL NOT NULL,
              reading_score REAL NOT NULL,
              writing_score REAL NOT NULL,
              speaking_score REAL NOT NULL,
              reached_target INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    repo = MockTestRepository(Future.value(db));
  });

  tearDown(() => db.close());

  MockTest _makeTest({bool reachedTarget = false, String date = '2026-05-21'}) {
    return MockTest(
      date: date,
      listeningScore: 6.5,
      readingScore: 7.0,
      writingScore: 6.0,
      speakingScore: 6.5,
      reachedTarget: reachedTarget,
      createdAt: DateTime(2026, 5, 21),
    );
  }

  test('getAll returns empty list when table is empty', () async {
    final result = await repo.getAll();
    expect(result, isEmpty);
  });

  test('insert then getAll returns the test', () async {
    await repo.insert(_makeTest());
    final result = await repo.getAll();
    expect(result.length, 1);
    expect(result.first.listeningScore, 6.5);
    expect(result.first.readingScore, 7.0);
    expect(result.first.reachedTarget, false);
  });

  test('getAll orders by date DESC', () async {
    await repo.insert(_makeTest(date: '2026-05-01'));
    await repo.insert(_makeTest(date: '2026-05-21'));
    final result = await repo.getAll();
    expect(result.first.date, '2026-05-21');
    expect(result.last.date, '2026-05-01');
  });

  test('delete removes the test', () async {
    await repo.insert(_makeTest());
    final all = await repo.getAll();
    await repo.delete(all.first.id!);
    expect(await repo.getAll(), isEmpty);
  });

  test('insert assigns id', () async {
    await repo.insert(_makeTest());
    final result = await repo.getAll();
    expect(result.first.id, isNotNull);
  });

  test('reachedTarget=true round-trips correctly', () async {
    await repo.insert(_makeTest(reachedTarget: true));
    final result = await repo.getAll();
    expect(result.first.reachedTarget, true);
  });
}

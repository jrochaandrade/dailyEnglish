import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_english/models/player_stats.dart';
import 'package:daily_english/repositories/player_stats_repository.dart';

void main() {
  late Database db;
  late PlayerStatsRepository repo;

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
        },
      ),
    );
    repo = PlayerStatsRepository(Future.value(db));
  });

  tearDown(() => db.close());

  test('load returns default stats when table is empty', () async {
    final stats = await repo.load();
    expect(stats.xp, 0);
    expect(stats.streak, 0);
    expect(stats.shields, 0);
    expect(stats.streakAtRisk, false);
  });

  test('load returns inserted singleton after save', () async {
    await repo.save(const PlayerStats(xp: 200, streak: 7, shields: 2));
    final stats = await repo.load();
    expect(stats.xp, 200);
    expect(stats.streak, 7);
    expect(stats.shields, 2);
  });

  test('save upserts — second save overwrites first', () async {
    await repo.save(const PlayerStats(xp: 50, streak: 1));
    await repo.save(const PlayerStats(xp: 100, streak: 3));
    final stats = await repo.load();
    expect(stats.xp, 100);
    expect(stats.streak, 3);
  });

  test('save persists lastActivityDate', () async {
    await repo.save(const PlayerStats(lastActivityDate: '2026-05-10'));
    final stats = await repo.load();
    expect(stats.lastActivityDate, '2026-05-10');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_english/core/database/app_database.dart';
import 'package:daily_english/core/services/offline_study_service.dart';
import 'package:daily_english/core/services/study_content_api_service.dart';

class MemoryDatabase extends AppDatabase {
  MemoryDatabase(this.db);
  final Database db;
  @override
  Future<Database> get database async => db;
}

class CorrectAnswerApi extends StudyContentApiService {
  @override
  Future<QuestionAnswerResult> submitResponse({
    required String clientEventId,
    required int generatedContentId,
    required String itemType,
    required int itemIndex,
    String? userAnswer,
    String? selfEvaluation,
    String? answeredAt,
  }) async =>
      const QuestionAnswerResult(
          isCorrect: true,
          answer: 'B',
          explanation: 'Representação do ofendido');
}

void main() {
  test('server correction survives reopening history and syncing twice',
      () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('''CREATE TABLE study_responses (
      client_event_id TEXT PRIMARY KEY, generated_content_id INTEGER,
      item_type TEXT, item_index INTEGER, user_answer TEXT,
      self_evaluation TEXT, is_correct INTEGER, answered_at TEXT, synced INTEGER
    )''');
    await db.execute(
        'CREATE TABLE study_contents (id INTEGER PRIMARY KEY, payload TEXT, updated_at TEXT)');
    await db.insert('study_contents',
        {'id': 1, 'payload': '{"questions":[{"question":"Teste"}]}'});
    final database = MemoryDatabase(db);
    final service =
        OfflineStudyService(database: database, api: CorrectAnswerApi());
    await service.recordResponse(
        generatedContentId: 1,
        itemType: 'question',
        itemIndex: 0,
        userAnswer: 'B',
        isCorrect: false);
    expect(await service.syncPending(), 1);
    final reopened =
        OfflineStudyService(database: database, api: CorrectAnswerApi());
    final history = await reopened.loadResponses();
    expect(history.single['is_correct'], 1);
    expect(history.single['user_answer'], 'B');
    expect(history.single['synced'], 1);
    expect((await db.query('study_contents')).single['payload'],
        contains('"answer":"B"'));
    await reopened.cacheContents([
      {
        'id': 1,
        'questions': [
          {'question': 'Teste'}
        ]
      }
    ]);
    expect((await db.query('study_contents')).single['payload'],
        contains('"answer":"B"'));
    expect(await reopened.syncPending(), 0);
    expect((await reopened.loadResponses()).length, 1);
  });
}

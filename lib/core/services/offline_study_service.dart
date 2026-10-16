import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'study_content_api_service.dart';

class OfflineStudyService {
  OfflineStudyService({AppDatabase? database, StudyContentApiService? api})
      : _database = database ?? AppDatabase(),
        _api = api ?? StudyContentApiService();

  final AppDatabase _database;
  final StudyContentApiService _api;
  static const _uuid = Uuid();

  Future<String> recordResponse({
    required int generatedContentId,
    required String itemType,
    required int itemIndex,
    String? userAnswer,
    String? selfEvaluation,
    bool? isCorrect,
    DateTime? answeredAt,
  }) async {
    final id = _uuid.v4();
    final db = await _database.database;
    await db.insert('study_responses', {
      'client_event_id': id,
      'generated_content_id': generatedContentId,
      'item_type': itemType,
      'item_index': itemIndex,
      'user_answer': userAnswer,
      'self_evaluation': selfEvaluation,
      'is_correct': isCorrect == null ? null : (isCorrect ? 1 : 0),
      'answered_at': (answeredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'synced': 0,
    });
    return id;
  }

  Future<int> syncPending() async {
    final db = await _database.database;
    final rows = await db.query('study_responses',
        where: 'synced = 0', orderBy: 'answered_at');
    var synced = 0;
    for (final row in rows) {
      try {
        final result = await _api.submitResponse(
          clientEventId: row['client_event_id'] as String,
          generatedContentId: row['generated_content_id'] as int,
          itemType: row['item_type'] as String,
          itemIndex: row['item_index'] as int,
          userAnswer: row['user_answer'] as String?,
          selfEvaluation: row['self_evaluation'] as String?,
          answeredAt: row['answered_at'] as String,
        );
        await confirmResponse(
            row['client_event_id'] as String, result.isCorrect,
            answer: result.answer, explanation: result.explanation);
        synced++;
      } catch (_) {
        break;
      }
    }
    return synced;
  }

  Future<void> confirmResponse(String clientEventId, bool isCorrect,
      {String answer = '', String explanation = ''}) async {
    final db = await _database.database;
    if (answer.isNotEmpty) {
      final rows = await db.query('study_responses',
          where: 'client_event_id = ?', whereArgs: [clientEventId]);
      if (rows.isNotEmpty && rows.single['item_type'] == 'question') {
        final row = rows.single;
        final cached = await db.query('study_contents',
            where: 'id = ?', whereArgs: [row['generated_content_id']]);
        if (cached.isNotEmpty) {
          final payload = jsonDecode(cached.single['payload'] as String)
              as Map<String, dynamic>;
          final questions = payload['questions'] as List? ?? [];
          final index = row['item_index'] as int;
          if (index >= 0 && index < questions.length) {
            questions[index]['answer'] = answer;
            questions[index]['explanation'] = explanation;
            await db.update('study_contents', {'payload': jsonEncode(payload)},
                where: 'id = ?', whereArgs: [row['generated_content_id']]);
          }
        }
      }
    }
    await db.update(
        'study_responses',
        {
          'synced': 1,
          'is_correct': isCorrect ? 1 : 0,
        },
        where: 'client_event_id = ?',
        whereArgs: [clientEventId]);
  }

  Future<String> recordTimeLog({
    int? generatedContentId,
    required int durationSeconds,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final id = _uuid.v4();
    final db = await _database.database;
    await db.insert('study_time_logs', {
      'client_event_id': id,
      'generated_content_id': generatedContentId,
      'duration_seconds': durationSeconds,
      'started_at': startedAt?.toUtc().toIso8601String(),
      'completed_at': (endedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'synced': 0,
    });
    return id;
  }

  Future<int> syncPendingTimeLogs() async {
    final db = await _database.database;
    final rows = await db.query('study_time_logs',
        where: 'synced = 0', orderBy: 'completed_at');
    var synced = 0;
    for (final row in rows) {
      try {
        await _api.submitTimeLog(
          clientEventId: row['client_event_id'] as String,
          generatedContentId: row['generated_content_id'] as int?,
          durationSeconds: row['duration_seconds'] as int,
          startedAt: row['started_at'] as String?,
          endedAt: row['completed_at'] as String?,
        );
        await db.update('study_time_logs', {'synced': 1},
            where: 'client_event_id = ?', whereArgs: [row['client_event_id']]);
        synced++;
      } catch (_) {
        break;
      }
    }
    return synced;
  }

  Future<List<Map<String, dynamic>>> loadResponses() async {
    final db = await _database.database;
    return db.query('study_responses', orderBy: 'answered_at DESC');
  }

  Future<List<Map<String, dynamic>>> loadTimeLogs() async {
    final db = await _database.database;
    return db.query('study_time_logs', orderBy: 'completed_at DESC');
  }

  Future<void> cacheContents(List<Map<String, dynamic>> contents) async {
    final db = await _database.database;
    for (final content in contents) {
      final previous = await db
          .query('study_contents', where: 'id = ?', whereArgs: [content['id']]);
      if (previous.isNotEmpty) {
        final old = jsonDecode(previous.single['payload'] as String)
            as Map<String, dynamic>;
        final oldQuestions = old['questions'] as List? ?? [];
        final questions = content['questions'] as List? ?? [];
        for (var index = 0;
            index < questions.length && index < oldQuestions.length;
            index++) {
          final question = questions[index];
          final oldQuestion = oldQuestions[index];
          if (question['question'] == oldQuestion['question'] &&
              jsonEncode(question['options']) ==
                  jsonEncode(oldQuestion['options']) &&
              question['answer'] == null &&
              oldQuestion['answer'] != null) {
            question['answer'] = oldQuestion['answer'];
            question['explanation'] = oldQuestion['explanation'];
          }
        }
      }
      await db.insert(
          'study_contents',
          {
            'id': content['id'],
            'payload': jsonEncode(content),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

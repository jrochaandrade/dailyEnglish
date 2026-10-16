import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../../models/study_structure.dart';
import 'api_config.dart';

class StudyStructureApiService {
  StudyStructureApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<List<StudyStructure>> list() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyStructureApiException('auth_required');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/study-structure'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );
      if (response.statusCode == 401)
        throw const StudyStructureApiException('auth_required');
      if (response.statusCode != 200)
        throw StudyStructureApiException(
            'request_failed_${response.statusCode}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['data'] as List<dynamic>? ?? [];
      await _cache(items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList());
      return items
          .map((item) => StudyStructure.fromJson(item as Map<String, dynamic>))
          .toList();
    } on StudyStructureApiException {
      rethrow;
    } catch (_) {
      return _cached();
    }
  }

  Future<List<StudyStructure>> cachedList() => _cached();

  Future<void> _cache(List<Map<String, dynamic>> items) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      for (final item in items) {
        final id = item['id'];
        if (id is! int) continue;
        await txn.insert(
            'study_structure_cache',
            {
              'id': id,
              'payload': jsonEncode(item),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<StudyStructure>> _cached() async {
    final db = await AppDatabase().database;
    final rows =
        await db.query('study_structure_cache', orderBy: 'updated_at DESC');
    if (rows.isEmpty)
      throw const StudyStructureApiException('offline_no_cache');
    return rows
        .map((row) => StudyStructure.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDiscipline(String name) =>
      _send('POST', '/disciplines', {'name': name});

  Future<void> updateDiscipline(int id, String name) =>
      _send('PATCH', '/disciplines/$id', {'name': name});

  Future<void> deleteDiscipline(int id) =>
      _send('DELETE', '/disciplines/$id', {});

  Future<void> createTopic(int disciplineId, String name) =>
      _send('POST', '/disciplines/$disciplineId/topics', {'name': name});

  Future<void> updateTopic(int id, String name) =>
      _send('PATCH', '/topics/$id', {'name': name});

  Future<void> moveTopic(int id, int disciplineId) =>
      _send('PATCH', '/topics/$id/move', {'discipline_id': '$disciplineId'});

  Future<void> deleteTopic(int id) => _send('DELETE', '/topics/$id', {});

  Future<void> _send(
      String method, String path, Map<String, String> data) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyStructureApiException('auth_required');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$baseUrl$path');
    final response = switch (method) {
      'POST' => await http.post(uri, headers: headers, body: jsonEncode(data)),
      'PATCH' =>
        await http.patch(uri, headers: headers, body: jsonEncode(data)),
      _ => await http.delete(uri, headers: headers),
    };
    if (response.statusCode == 401) {
      throw const StudyStructureApiException('auth_required');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudyStructureApiException('request_failed_${response.statusCode}');
    }
  }
}

class StudyStructureApiException implements Exception {
  final String code;
  const StudyStructureApiException(this.code);
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../../models/material.dart';
import 'api_config.dart';

class MaterialApiService {
  MaterialApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<String?> _token() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('api_token');
  }

  Future<List<StudyMaterial>> list() async {
    final token = await _token();
    if (token == null) throw const MaterialApiException('auth_required');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/materials'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );
      if (response.statusCode == 401)
        throw const MaterialApiException('auth_required');
      if (response.statusCode != 200)
        throw MaterialApiException('request_failed_${response.statusCode}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['data'] as List<dynamic>? ?? [];
      await _cache(items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList());
      return items
          .map((item) => StudyMaterial.fromJson(item as Map<String, dynamic>))
          .toList();
    } on MaterialApiException {
      rethrow;
    } catch (_) {
      return _cached();
    }
  }

  Future<List<StudyMaterial>> cachedList() => _cached();

  Future<void> _cache(List<Map<String, dynamic>> items) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      for (final item in items) {
        final id = item['id'];
        if (id is! int) continue;
        await txn.insert(
            'materials_cache',
            {
              'id': id,
              'payload': jsonEncode(item),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<StudyMaterial>> _cached() async {
    final db = await AppDatabase().database;
    final rows = await db.query('materials_cache', orderBy: 'updated_at DESC');
    if (rows.isEmpty) throw const MaterialApiException('offline_no_cache');
    return rows
        .map((row) => StudyMaterial.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<StudyMaterial> upload({
    File? file,
    String? title,
    int? disciplineId,
    int? topicId,
    String sourceType = 'pdf',
    String? content,
  }) async {
    final token = await _token();
    if (token == null) throw const MaterialApiException('auth_required');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/materials'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['source_type'] = sourceType;
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }
    if (title != null && title.trim().isNotEmpty) {
      request.fields['title'] = title.trim();
    }
    if (disciplineId != null) request.fields['discipline_id'] = '$disciplineId';
    if (topicId != null) request.fields['topic_id'] = '$topicId';
    if (content != null) request.fields['content'] = content;
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 401) {
      throw const MaterialApiException('auth_required');
    }
    if (response.statusCode != 201) {
      throw MaterialApiException('request_failed_${response.statusCode}');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return StudyMaterial.fromJson(json['data'] as Map<String, dynamic>);
  }
}

class MaterialApiException implements Exception {
  final String code;
  const MaterialApiException(this.code);
}

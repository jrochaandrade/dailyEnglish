import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'api_config.dart';

class EnglishSyncApiService {
  EnglishSyncApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  static const tables = [
    'words',
    'phrases',
    'phrasal_verbs',
    'categories',
    'diary_entries',
    'player_stats',
    'study_sessions',
    'mock_tests',
    'contest_cards',
  ];

  Future<Map<String, dynamic>> syncLocalDatabase() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null || token.isEmpty) {
      throw const EnglishSyncException('Faça login para sincronizar os dados.');
    }

    final db = await AppDatabase().database;
    final snapshot = <String, dynamic>{
      'schema_version': 17,
      'tables': <String, dynamic>{},
    };
    final snapshotTables = snapshot['tables'] as Map<String, dynamic>;
    for (final table in tables) {
      final rows = await db.query(table);
      snapshotTables[table] =
          rows.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/english/sync'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(snapshot),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw const EnglishSyncException(
          'Sua sessão expirou. Faça login novamente.');
    }
    if (response.statusCode != 200) {
      throw EnglishSyncException(
          'Falha ao sincronizar (${response.statusCode}).');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> downloadSnapshot() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null || token.isEmpty) {
      throw const EnglishSyncException('Faça login para baixar os dados.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/english/sync'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw EnglishSyncException(
          'Falha ao baixar os dados (${response.statusCode}).');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<int> downloadAndMerge() async {
    final snapshot = await downloadSnapshot();
    final tables = snapshot['tables'] as Map<String, dynamic>? ?? {};
    final db = await AppDatabase().database;
    var saved = 0;

    await db.transaction((txn) async {
      for (final table in tables.entries) {
        if (!EnglishSyncApiService.tables.contains(table.key)) continue;
        final rows = table.value as List<dynamic>? ?? [];
        for (final item in rows) {
          if (item is! Map<String, dynamic>) continue;
          await txn.insert(
            table.key,
            Map<String, Object?>.from(item),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          saved++;
        }
      }
    });

    return saved;
  }
}

class EnglishSyncException implements Exception {
  final String message;
  const EnglishSyncException(this.message);
}

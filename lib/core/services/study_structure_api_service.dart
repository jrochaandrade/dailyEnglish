import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

    final response = await http.get(
      Uri.parse('$baseUrl/study-structure'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      throw const StudyStructureApiException('auth_required');
    }
    if (response.statusCode != 200) {
      throw StudyStructureApiException('request_failed_${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>? ?? [])
        .map((item) => StudyStructure.fromJson(item as Map<String, dynamic>))
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

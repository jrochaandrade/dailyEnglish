import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/study_content.dart';
import 'api_config.dart';

class StudyContentApiService {
  StudyContentApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<List<StudyContent>> list() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyContentApiException('auth_required');

    final response = await http.get(
      Uri.parse('$baseUrl/study-content'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      throw const StudyContentApiException('auth_required');
    }
    if (response.statusCode != 200) {
      throw StudyContentApiException('request_failed_${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>? ?? [])
        .map((item) => StudyContent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> setStudyEnabled(int contentId, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyContentApiException('auth_required');
    final response = await http.patch(
      Uri.parse('$baseUrl/study-content/$contentId/study-cycle'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'study_enabled': enabled}),
    );
    if (response.statusCode == 401) {
      throw const StudyContentApiException('auth_required');
    }
    if (response.statusCode != 200) {
      throw StudyContentApiException('request_failed_${response.statusCode}');
    }
  }
}

class StudyContentApiException implements Exception {
  final String code;
  const StudyContentApiException(this.code);
}

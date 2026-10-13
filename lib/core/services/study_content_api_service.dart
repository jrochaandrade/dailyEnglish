import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/study_content.dart';
import 'api_config.dart';

class StudyContentApiService {
  StudyContentApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<List<StudyContent>> list({bool includeAll = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyContentApiException('auth_required');

    final response = await http.get(
      Uri.parse('$baseUrl/study-content${includeAll ? '?include_all=1' : ''}'),
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

  Future<void> completeStudyContent(int contentId, {int quality = 4}) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyContentApiException('auth_required');
    final response = await http.post(
      Uri.parse('$baseUrl/study-content/$contentId/complete'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'quality': quality}),
    );
    if (response.statusCode == 401) {
      throw const StudyContentApiException('auth_required');
    }
    if (response.statusCode != 200) {
      throw StudyContentApiException('request_failed_${response.statusCode}');
    }
  }

  Future<MindMapFile> downloadMindMap(int materialId) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyContentApiException('auth_required');
    final response = await http.get(
      Uri.parse('$baseUrl/materials/$materialId/mind-map'),
      headers: {'Accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      throw const StudyContentApiException('auth_required');
    }
    if (response.statusCode != 200) {
      throw StudyContentApiException('request_failed_${response.statusCode}');
    }

    return MindMapFile(
      bytes: response.bodyBytes,
      mimeType: response.headers['content-type']?.split(';').first,
    );
  }

  Future<QuestionAnswerResult> submitQuestionAnswer({
    required int generatedContentId,
    required int itemIndex,
    required String userAnswer,
    String? answeredAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const StudyContentApiException('auth_required');
    final response = await http.post(
      Uri.parse('$baseUrl/study-responses'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'generated_content_id': generatedContentId,
        'item_type': 'question',
        'item_index': itemIndex,
        'user_answer': userAnswer,
        if (answeredAt != null) 'answered_at': answeredAt,
      }),
    );
    if (response.statusCode == 401) {
      throw const StudyContentApiException('auth_required');
    }
    if (response.statusCode != 201) {
      throw StudyContentApiException('request_failed_${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};

    return QuestionAnswerResult(
      isCorrect: data['is_correct'] as bool? ?? false,
      answer: data['answer'] as String? ?? '',
      explanation: data['explanation'] as String? ?? '',
    );
  }
}

class MindMapFile {
  final Uint8List bytes;
  final String? mimeType;

  const MindMapFile({required this.bytes, this.mimeType});
}

class QuestionAnswerResult {
  final bool isCorrect;
  final String answer;
  final String explanation;

  const QuestionAnswerResult({
    required this.isCorrect,
    required this.answer,
    required this.explanation,
  });
}

class StudyContentApiException implements Exception {
  final String code;
  const StudyContentApiException(this.code);
}

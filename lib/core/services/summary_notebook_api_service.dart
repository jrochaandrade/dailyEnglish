import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/summary_notebook.dart';
import 'api_config.dart';

class SummaryNotebookApiService {
  SummaryNotebookApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<List<SummaryNotebook>> list() async {
    final response = await _request('GET', '/summary-notebooks');
    _check(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>? ?? [])
        .map((item) => SummaryNotebook.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SummaryNotebook> create({
    required String name,
    required List<int> sourceContentIds,
    bool includeVisual = false,
  }) async {
    final response = await _request('POST', '/summary-notebooks', body: {
      'name': name,
      'source_content_ids': sourceContentIds,
      'include_visual': includeVisual,
    });
    _check(response);
    return SummaryNotebook.fromJson((jsonDecode(response.body)
        as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<SummaryNotebook> createEmpty(String name) async {
    final response = await _request('POST', '/summary-notebooks/empty', body: {
      'name': name,
    });
    _check(response);
    return SummaryNotebook.fromJson((jsonDecode(response.body)
        as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<SummaryNotebook> update(
    int id, {
    String? name,
    List<int>? sourceContentIds,
    bool? includeVisual,
    bool regenerate = false,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (sourceContentIds != null) 'source_content_ids': sourceContentIds,
      if (includeVisual != null) 'include_visual': includeVisual,
      if (regenerate) 'regenerate': true,
    };
    final response =
        await _request('PUT', '/summary-notebooks/$id', body: body);
    _check(response);
    return SummaryNotebook.fromJson((jsonDecode(response.body)
        as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<SummaryNotebook> appendEntry(
    int notebookId, {
    required String type,
    required String prompt,
    required String answer,
    String explanation = '',
  }) async {
    final response =
        await _request('POST', '/summary-notebooks/$notebookId/entries', body: {
      'type': type,
      'prompt': prompt,
      'answer': answer,
      'explanation': explanation,
    });
    _check(response);
    return SummaryNotebook.fromJson((jsonDecode(response.body)
        as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<http.Response> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('api_token');
    if (token == null) throw const SummaryNotebookApiException('auth_required');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$baseUrl$path');
    return switch (method) {
      'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => http.put(uri, headers: headers, body: jsonEncode(body)),
      _ => http.get(uri, headers: headers),
    };
  }

  void _check(http.Response response) {
    if (response.statusCode == 401) {
      throw const SummaryNotebookApiException('auth_required');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SummaryNotebookApiException(
          'request_failed_${response.statusCode}');
    }
  }
}

class SummaryNotebookApiException implements Exception {
  final String code;
  const SummaryNotebookApiException(this.code);
}

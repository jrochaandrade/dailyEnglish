import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthApiService {
  AuthApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    await _storeToken(response);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      }),
    );
    await _storeToken(response);
  }

  Future<void> _storeToken(http.Response response) async {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthApiException(response.statusCode == 422
          ? 'Dados inválidos ou credenciais incorretas.'
          : 'Não foi possível conectar ao backend.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const AuthApiException('O backend não retornou um token.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('api_token', token);
  }
}

class AuthApiException implements Exception {
  final String message;
  const AuthApiException(this.message);
}

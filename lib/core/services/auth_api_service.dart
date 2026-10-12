import 'dart:async';
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
    final response = await _post(
      '/auth/login',
      {'email': email, 'password': password},
    );
    await _storeToken(response);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
    });
    await _storeToken(response);
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('api_token');
  }

  Future<http.Response> _post(String path, Map<String, String> body) async {
    try {
      return await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AuthApiException(
          'Tempo esgotado. Verifique se o celular está na mesma rede Wi-Fi e se o backend está rodando.');
    } on http.ClientException {
      throw const AuthApiException(
          'Não foi possível acessar o backend. Confira a rede e o endereço da API.');
    }
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

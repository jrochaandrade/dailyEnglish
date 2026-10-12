import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final translationServiceProvider =
    Provider<TranslationService>((ref) => TranslationService());

class TranslationService {
  Future<String> translate(String text,
      {String from = 'en', String to = 'pt'}) async {
    final url = Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(text)}',
    );
    final response =
        await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
    if (response.statusCode != 200) {
      throw Exception('Translation failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List;
    return (data[0] as List)
        .map((s) => (s as List?)?.first as String? ?? '')
        .join('');
  }
}

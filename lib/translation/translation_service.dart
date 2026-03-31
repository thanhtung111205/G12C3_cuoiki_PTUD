import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationResult {
  final String translatedText;
  final String? explanation;

  TranslationResult({required this.translatedText, this.explanation});
}

class TranslationService {
  final String endpoint;
  final String apiKey; // optional, some APIs require an API key

  TranslationService({required this.endpoint, this.apiKey = ''});

  /// Call a translation API.
  Future<TranslationResult> translate({
    required String selected,
    required String context,
    String target = 'vi',
  }) async {
    final uri = Uri.parse(endpoint);
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'flutter-app/1.0',
    };
    if (apiKey.isNotEmpty) headers['Authorization'] = 'Bearer $apiKey';

    http.Response resp;
    try {
      if (endpoint.contains('mymemory.translated.net')) {
        // MyMemory GET endpoint has a length limit.
        // If the query is too long, we don't send context to avoid 414 or empty responses.
        final String query = (selected.length > 500) ? selected : selected;
        
        final Map<String, String> params = {
          'q': query,
          'langpair': 'en|$target',
        };
        
        // Add context if query isn't too long
        if (selected.length < 300 && context.isNotEmpty) {
           params['context'] = context;
        }

        final uriWithParams = uri.replace(queryParameters: params);
        
        resp = await http.get(uriWithParams, headers: headers).timeout(const Duration(seconds: 15));
      } else {
        final body = jsonEncode({
          'q': selected,
          'context': context,
          'target': target,
        });
        resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      throw Exception('Lỗi kết nối hoặc Timeout. Hãy thử chọn đoạn ngắn hơn.');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      
      if (endpoint.contains('mymemory.translated.net')) {
        final translated = (data['responseData']?['translatedText'])?.toString() ?? '';
        if (translated.isEmpty || translated.contains('MYMEMORY WARNING')) {
           // MyMemory sometimes returns a warning in the text instead of translating
           throw Exception('Máy chủ bận hoặc giới hạn ký tự. Vui lòng thử lại sau.');
        }
        return TranslationResult(translatedText: translated);
      }

      if (data is Map<String, dynamic>) {
        return TranslationResult(
          translatedText: data['translatedText']?.toString() ?? data['translation']?.toString() ?? '',
          explanation: data['explanation']?.toString(),
        );
      }
      return TranslationResult(translatedText: data.toString());
    }
    
    if (resp.statusCode == 414 || resp.statusCode == 431) {
      throw Exception('Đoạn văn quá dài. Vui lòng chọn đoạn ngắn hơn.');
    }
    
    throw Exception('Lỗi máy chủ dịch (${resp.statusCode}).');
  }
}

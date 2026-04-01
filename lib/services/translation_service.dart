import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  Future<String> translate(String text,
      {String from = 'en', String to = 'vi'}) async {
    if (text.isEmpty) {
      return '';
    }
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$from|$to'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['responseStatus'] == 200) {
          return data['responseData']['translatedText'];
        }
      }
      // Fallback to original text if translation fails
      return text;
    } catch (e) {
      print('Translation error: $e');
      // Fallback to original text on error
      return text;
    }
  }
}

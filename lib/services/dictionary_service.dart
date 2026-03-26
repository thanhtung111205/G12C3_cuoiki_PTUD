import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dictionary_entry.dart';

class WordNotFoundException implements Exception {
  final String message;
  WordNotFoundException(this.message);
}

class DictionaryService {
  Future<DictionaryEntry> lookupWord(String word) async {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) {
        throw Exception("Word is empty");
    }
    final url = 'https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord';
    
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final entry = data[0];
          
          // Extract phonetic (try to find one with audio and text)
          String phonetic = '';
          String audioUrl = '';
          
          if (entry.containsKey('phonetics') && entry['phonetics'] is List) {
             for (var p in entry['phonetics']) {
                if (p['text'] != null && phonetic.isEmpty) phonetic = p['text'];
                if (p['audio'] != null && p['audio'].toString().isNotEmpty && audioUrl.isEmpty) {
                  audioUrl = p['audio'];
                }
             }
          }
          if (phonetic.isEmpty && entry.containsKey('phonetic')) {
            phonetic = entry['phonetic'];
          }

          // Extract first definition
          String partOfSpeech = '';
          String definitionText = '';
          
          if (entry.containsKey('meanings') && entry['meanings'] is List && entry['meanings'].isNotEmpty) {
            final meaning = entry['meanings'][0];
            partOfSpeech = meaning['partOfSpeech'] ?? '';
            
            if (meaning.containsKey('definitions') && meaning['definitions'] is List && meaning['definitions'].isNotEmpty) {
              definitionText = meaning['definitions'][0]['definition'] ?? '';
            }
          }

          return DictionaryEntry(
            word: entry['word'] ?? word,
            phonetic: phonetic,
            partOfSpeech: partOfSpeech,
            definition: definitionText,
            audioUrl: audioUrl,
          );
        }
      } else if (response.statusCode == 404) {
        throw WordNotFoundException('Word not found in dictionary');
      }
      
      throw Exception('Failed to lookup word: ${response.statusCode}');
    } catch (e) {
      if (e is WordNotFoundException) rethrow;
      throw Exception('Error looking up word: $e');
    }
  }
}

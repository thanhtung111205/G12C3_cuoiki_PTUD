import 'dart:async';

import 'translation_service.dart';

/// A small mock translation service used for offline UI testing.
/// Returns a quick heuristic translation or a prefixed placeholder.
class MockTranslationService extends TranslationService {
  MockTranslationService() : super(endpoint: 'mock');

  static final Map<String, String> _idioms = <String, String>{
    'break the ice': 'phá vỡ sự ngượng/ngại; làm quen',
    'quick brown fox': 'con cáo nâu nhanh',
  };

  static final Map<String, String> _dictionary = <String, String>{
    'hello': 'xin chào',
    'world': 'thế giới',
    'apple': 'táo',
    'dog': 'chó',
    'cat': 'mèo',
  };

  @override
  Future<TranslationResult> translate({required String selected, required String context, String target = 'vi'}) async {
    // simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final s = selected.trim();
    final lower = s.toLowerCase();

    // idiom detection (simple exact match)
    for (final idiom in _idioms.keys) {
      if (lower.contains(idiom)) {
        final meaning = _idioms[idiom]!;
        final translated = meaning; // prefer idiom meaning
        final explanation = 'Cụm từ idiom: "$idiom" → $meaning';
        return TranslationResult(translatedText: translated, explanation: explanation);
      }
    }

    // try simple dictionary word-by-word
    final words = RegExp(r"[A-Za-zÀ-ỹ]+|[^A-Za-zÀ-ỹ]+")
        .allMatches(s)
        .map((m) => m.group(0)!)
        .toList();

    final buffer = StringBuffer();
    for (final token in words) {
      final key = token.toLowerCase();
      if (_dictionary.containsKey(key)) {
        buffer.write(_dictionary[key]);
      } else {
        buffer.write(token); // leave punctuation/unknown words as-is
      }
    }
    final piece = buffer.toString().trim();
    if (piece.isNotEmpty) {
      return TranslationResult(translatedText: piece, explanation: null);
    }

    // fallback: prefix with (VI)
    return TranslationResult(translatedText: '(VI) $s', explanation: null);
  }
}

class TranslationCacheEntry {
  final String key; // combined key of selected + context
  final String translated;
  final String? explanation;

  TranslationCacheEntry({
    required this.key,
    required this.translated,
    this.explanation,
  });
}

class TranslationCache {
  final Map<String, TranslationCacheEntry> _cache = {};

  String _makeKey(String selected, String context) =>
      '$selected\u0002$context';

  TranslationCacheEntry? get(String selected, String context) {
    return _cache[_makeKey(selected, context)];
  }

  void set(
    String selected,
    String context,
    String translated, [
    String? explanation,
  ]) {
    final key = _makeKey(selected, context);
    _cache[key] = TranslationCacheEntry(
      key: key,
      translated: translated,
      explanation: explanation,
    );
  }

  void clear() => _cache.clear();
}

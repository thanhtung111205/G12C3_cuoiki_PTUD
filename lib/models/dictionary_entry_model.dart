class DictionaryEntry {
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String definition;
  final String example;
  final String audioUrl;

  const DictionaryEntry({
    required this.word,
    this.phonetic = '',
    this.partOfSpeech = '',
    this.definition = '',
    this.example = '',
    this.audioUrl = '',
  });

  DictionaryEntry copyWith({
    String? word,
    String? phonetic,
    String? partOfSpeech,
    String? definition,
    String? example,
    String? audioUrl,
  }) {
    return DictionaryEntry(
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }

  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      word: map['word'] as String? ?? '',
      phonetic: map['phonetic'] as String? ?? '',
      partOfSpeech: map['partOfSpeech'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      example: map['example'] as String? ?? '',
      audioUrl: map['audioUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'phonetic': phonetic,
      'partOfSpeech': partOfSpeech,
      'definition': definition,
      'example': example,
      'audioUrl': audioUrl,
    };
  }
}

typedef DictionaryEntryModel = DictionaryEntry;

import 'package:flutter/foundation.dart';

class FlashcardProvider extends ChangeNotifier {
  FlashcardProvider._() {
    _decks = <FlashcardDeck>[
      FlashcardDeck(
        id: 'ielts-reading',
        title: 'Từ vựng IELTS Reading',
        cards: <FlashcardCard>[
          FlashcardCard(
            id: 'ielts-1',
            english: 'analyze',
            meaning: 'phân tích',
            example: 'Researchers analyze data before making conclusions.',
          ),
          FlashcardCard(
            id: 'ielts-2',
            english: 'impact',
            meaning: 'tác động',
            example: 'The impact of this policy is visible after one year.',
          ),
          FlashcardCard(
            id: 'ielts-3',
            english: 'evidence',
            meaning: 'bằng chứng',
            example: 'Strong evidence supports the main argument.',
          ),
          FlashcardCard(
            id: 'ielts-4',
            english: 'substantial',
            meaning: 'đáng kể',
            example: 'The report gives substantial detail about the topic.',
          ),
        ],
      ),
      FlashcardDeck(
        id: 'business-growth',
        title: 'Business Growth Essentials',
        cards: <FlashcardCard>[
          FlashcardCard(
            id: 'business-1',
            english: 'revenue',
            meaning: 'doanh thu',
            example: 'Revenue increased steadily during the last quarter.',
          ),
          FlashcardCard(
            id: 'business-2',
            english: 'strategy',
            meaning: 'chiến lược',
            example: 'A strong strategy keeps the team focused.',
          ),
          FlashcardCard(
            id: 'business-3',
            english: 'efficiency',
            meaning: 'hiệu suất',
            example: 'Efficiency improves when the process is simpler.',
          ),
        ],
      ),
      FlashcardDeck(
        id: 'travel-daily',
        title: 'Travel & Daily Life',
        cards: <FlashcardCard>[
          FlashcardCard(
            id: 'travel-1',
            english: 'destination',
            meaning: 'điểm đến',
            example: 'Our destination was only two hours away.',
          ),
          FlashcardCard(
            id: 'travel-2',
            english: 'commute',
            meaning: 'đi lại hằng ngày',
            example: 'I commute by bus to keep the routine simple.',
          ),
        ],
      ),
    ];
  }

  static final FlashcardProvider instance = FlashcardProvider._();

  factory FlashcardProvider() => instance;

  late final List<FlashcardDeck> _decks;
  String? _activeDeckId;

  List<FlashcardDeck> get decks => List<FlashcardDeck>.unmodifiable(_decks);

  FlashcardDeck get activeDeck => _resolveDeck(_activeDeckId) ?? _decks.first;

  void setActiveDeck(String deckId) {
    if (_activeDeckId == deckId) return;
    _activeDeckId = deckId;
    notifyListeners();
  }

  FlashcardDeck? deckById(String deckId) {
    for (final FlashcardDeck deck in _decks) {
      if (deck.id == deckId) return deck;
    }
    return null;
  }

  FlashcardDeck? _resolveDeck(String? deckId) {
    if (deckId == null) return null;
    return deckById(deckId);
  }

  int reviewedCount(String deckId) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return 0;
    return deck.cards.where((FlashcardCard card) => card.isReviewed).length;
  }

  double progressForDeck(String deckId) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null || deck.cards.isEmpty) return 0;
    return reviewedCount(deckId) / deck.cards.length;
  }

  void addDeck(String title) {
    _decks.insert(
      0,
      FlashcardDeck(
        id: _generateId('deck'),
        title: title.trim(),
        cards: <FlashcardCard>[],
      ),
    );
    notifyListeners();
  }

  void updateDeck(String deckId, String title) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return;
    deck.title = title.trim();
    notifyListeners();
  }

  void deleteDeck(String deckId) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return;

    _decks.remove(deck);
    if (_activeDeckId == deckId) {
      _activeDeckId = _decks.isEmpty ? null : _decks.first.id;
    }
    notifyListeners();
  }

  void addCard(
    String deckId, {
    required String english,
    required String meaning,
    String? example,
  }) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return;

    deck.cards.add(
      FlashcardCard(
        id: _generateId('card'),
        english: english.trim(),
        meaning: meaning.trim(),
        example: (example ?? _generateExampleSentence(english, meaning)).trim(),
      ),
    );
    notifyListeners();
  }

  void insertCardAt(String deckId, int index, FlashcardCard card) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return;

    final int safeIndex = index.clamp(0, deck.cards.length);
    deck.cards.insert(safeIndex, card);
    notifyListeners();
  }

  void updateCard(
    String deckId,
    String cardId, {
    required String english,
    required String meaning,
  }) {
    final FlashcardCard? card = cardById(deckId, cardId);
    if (card == null) return;

    card.english = english.trim();
    card.meaning = meaning.trim();
    card.example = _generateExampleSentence(english, meaning).trim();
    notifyListeners();
  }

  void deleteCard(String deckId, String cardId) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return;

    deck.cards.removeWhere((FlashcardCard card) => card.id == cardId);
    notifyListeners();
  }

  void markCardReviewed(
    String deckId,
    String cardId, {
    required bool remembered,
  }) {
    final FlashcardCard? card = cardById(deckId, cardId);
    if (card == null) return;

    card.isReviewed = true;
    card.rememberedLastTime = remembered;
    notifyListeners();
  }

  FlashcardCard? cardById(String deckId, String cardId) {
    final FlashcardDeck? deck = deckById(deckId);
    if (deck == null) return null;

    for (final FlashcardCard card in deck.cards) {
      if (card.id == cardId) return card;
    }
    return null;
  }

  String _generateId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _generateExampleSentence(String english, String meaning) {
    final String normalizedEnglish = english.trim();
    final String normalizedMeaning = meaning.trim();
    if (normalizedEnglish.isEmpty) {
      return 'Example sentence will appear here.';
    }
    return 'I use $normalizedEnglish when I talk about $normalizedMeaning.';
  }
}

class FlashcardDeck {
  FlashcardDeck({required this.id, required this.title, required this.cards});

  final String id;
  String title;
  final List<FlashcardCard> cards;

  int get reviewedCount =>
      cards.where((FlashcardCard card) => card.isReviewed).length;

  double get progress => cards.isEmpty ? 0 : reviewedCount / cards.length;
}

class FlashcardCard {
  FlashcardCard({
    required this.id,
    required this.english,
    required this.meaning,
    required this.example,
    this.isReviewed = false,
    this.rememberedLastTime,
  });

  final String id;
  String english;
  String meaning;
  String example;
  bool isReviewed;
  bool? rememberedLastTime;
}

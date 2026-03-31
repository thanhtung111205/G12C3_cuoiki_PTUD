import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FlashcardProvider extends ChangeNotifier {
  FlashcardProvider._();

  static final FlashcardProvider instance = FlashcardProvider._();

  factory FlashcardProvider() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, FlashcardDeck> _decks = <String, FlashcardDeck>{};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _cardSubscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deckSubscription;
  List<String> _deckOrder = <String>[];
  String? _syncedUserId;
  String? _activeDeckId;

  String? get currentUserId => _auth.currentUser?.uid;

  String? get activeDeckId => _activeDeckId;

  List<FlashcardDeck> get decks => _deckOrder
      .map((String deckId) => _decks[deckId])
      .whereType<FlashcardDeck>()
      .toList(growable: false);

  FlashcardDeck get activeDeck =>
      deckById(_activeDeckId) ??
      (decks.isNotEmpty
          ? decks.first
          : FlashcardDeck(
              id: '',
              title: 'Bộ từ vựng',
              cardCount: 0,
              reviewedCount: 0,
              updatedAt: null,
            ));

  void setActiveDeck(String deckId) {
    if (_activeDeckId == deckId) return;
    _activeDeckId = deckId;
    notifyListeners();
  }

  void syncForUser(String? userId) {
    if (userId == null) {
      _clearSubscriptions();
      return;
    }

    if (_syncedUserId == userId) return;

    _clearSubscriptions();
    _syncedUserId = userId;

    _deckSubscription = _deckCollection(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final Set<String> nextDeckIds = <String>{};
          final List<String> nextOrder = <String>[];

          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            final FlashcardDeck incomingDeck = FlashcardDeck.fromFirestore(doc);
            nextDeckIds.add(doc.id);
            nextOrder.add(doc.id);

            final FlashcardDeck existingDeck = _decks[doc.id] ?? incomingDeck;
            existingDeck.title = incomingDeck.title;
            existingDeck.cardCount = incomingDeck.cardCount;
            existingDeck.reviewedCount = incomingDeck.reviewedCount;
            existingDeck.updatedAt = incomingDeck.updatedAt;
            _decks[doc.id] = existingDeck;

            _ensureCardSubscription(userId, doc.id);
          }

          final List<String> removedDeckIds = _decks.keys
              .where((String deckId) => !nextDeckIds.contains(deckId))
              .toList(growable: false);
          for (final String removedDeckId in removedDeckIds) {
            _decks.remove(removedDeckId);
            _cardSubscriptions.remove(removedDeckId)?.cancel();
          }

          _deckOrder = nextOrder;
          if (_activeDeckId == null || !_decks.containsKey(_activeDeckId)) {
            _activeDeckId = _deckOrder.isNotEmpty ? _deckOrder.first : null;
          }

          notifyListeners();
        });
  }

  CollectionReference<Map<String, dynamic>> _deckCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('flashcard_decks');
  }

  DocumentReference<Map<String, dynamic>> _deckDoc(
    String userId,
    String deckId,
  ) {
    return _deckCollection(userId).doc(deckId);
  }

  CollectionReference<Map<String, dynamic>> _cardCollection(
    String userId,
    String deckId,
  ) {
    return _deckDoc(userId, deckId).collection('cards');
  }

  void _ensureCardSubscription(String userId, String deckId) {
    if (_cardSubscriptions.containsKey(deckId)) return;

    _cardSubscriptions[deckId] = _cardCollection(userId, deckId)
        .orderBy('createdAt')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final FlashcardDeck? deck = _decks[deckId];
          if (deck == null) return;

          deck.cards
            ..clear()
            ..addAll(snapshot.docs.map(FlashcardCard.fromFirestore));

          _activeDeckId ??= deckId;
          notifyListeners();
        });
  }

  void _clearSubscriptions() {
    _deckSubscription?.cancel();
    _deckSubscription = null;

    for (final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        subscription
        in _cardSubscriptions.values) {
      subscription.cancel();
    }
    _cardSubscriptions.clear();

    _decks.clear();
    _deckOrder = <String>[];
    _syncedUserId = null;
    _activeDeckId = null;
  }

  FlashcardDeck? deckById(String? deckId) {
    if (deckId == null) return null;
    return _decks[deckId];
  }

  int reviewedCount(String deckId) {
    return _decks[deckId]?.reviewedCount ?? 0;
  }

  double progressForDeck(String deckId) {
    return _decks[deckId]?.progress ?? 0;
  }

  Future<String> addDeck(String userId, {required String title}) async {
    final docRef = _deckCollection(userId).doc();
    await docRef.set(<String, dynamic>{
      'title': title.trim(),
      'cardCount': 0,
      'reviewedCount': 0,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    return docRef.id;
  }

  Future<void> updateDeck(String userId, String deckId, String title) async {
    await _deckDoc(userId, deckId).set(<String, dynamic>{
      'title': title.trim(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteDeck(String userId, String deckId) async {
    final QuerySnapshot<Map<String, dynamic>> cardsSnapshot =
        await _cardCollection(userId, deckId).get();
    for (int index = 0; index < cardsSnapshot.docs.length; index += 400) {
      final WriteBatch batch = _firestore.batch();
      final int end = math.min(index + 400, cardsSnapshot.docs.length);
      for (int i = index; i < end; i++) {
        batch.delete(cardsSnapshot.docs[i].reference);
      }
      await batch.commit();
    }
    await _deckDoc(userId, deckId).delete();
  }

  Future<String> addCard(
    String userId,
    String deckId, {
    required String english,
    required String meaning,
    String? example,
    String? audioUrl,
    String? phonetic,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc = _cardCollection(
      userId,
      deckId,
    ).doc();
    final String normalizedEnglish = english.trim();
    final String normalizedMeaning = meaning.trim();

    await _firestore.runTransaction((Transaction tx) async {
      tx.set(doc, <String, dynamic>{
        'english': normalizedEnglish,
        'meaning': normalizedMeaning,
        'example':
            (example ??
                    _generateExampleSentence(
                      normalizedEnglish,
                      normalizedMeaning,
                    ))
                .trim(),
        if (audioUrl != null && audioUrl.isNotEmpty) 'audioUrl': audioUrl,
        if (phonetic != null && phonetic.isNotEmpty) 'phonetic': phonetic,
        'isReviewed': false,
        'rememberedLastTime': null,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'reviewedAt': null,
      });

      tx.set(_deckDoc(userId, deckId), <String, dynamic>{
        'cardCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });

    return doc.id;
  }

  Future<void> restoreCard(
    String userId,
    String deckId,
    FlashcardCard card,
  ) async {
    final DocumentReference<Map<String, dynamic>> doc = _cardCollection(
      userId,
      deckId,
    ).doc(card.id);

    await _firestore.runTransaction((Transaction tx) async {
      tx.set(doc, card.toMap(), SetOptions(merge: false));
      tx.set(_deckDoc(userId, deckId), <String, dynamic>{
        'cardCount': FieldValue.increment(1),
        if (card.isReviewed) 'reviewedCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> insertCardAt(
    String userId,
    String deckId,
    int index,
    FlashcardCard card,
  ) async {
    await restoreCard(userId, deckId, card);
  }

  Future<void> updateCard(
    String userId,
    String deckId,
    String cardId, {
    required String english,
    required String meaning,
    String? example,
  }) async {
    final String normalizedEnglish = english.trim();
    final String normalizedMeaning = meaning.trim();

    await _cardCollection(userId, deckId).doc(cardId).set(<String, dynamic>{
      'english': normalizedEnglish,
      'meaning': normalizedMeaning,
      'example':
          (example ??
                  _generateExampleSentence(
                    normalizedEnglish,
                    normalizedMeaning,
                  ))
              .trim(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCard(String userId, String deckId, String cardId) async {
    final DocumentReference<Map<String, dynamic>> deckRef = _deckDoc(
      userId,
      deckId,
    );
    final DocumentReference<Map<String, dynamic>> cardRef = _cardCollection(
      userId,
      deckId,
    ).doc(cardId);

    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> cardSnapshot = await tx.get(
        cardRef,
      );
      if (!cardSnapshot.exists) return;

      final bool wasReviewed =
          (cardSnapshot.data()?['isReviewed'] as bool?) ?? false;

      tx.delete(cardRef);
      tx.set(deckRef, <String, dynamic>{
        'cardCount': FieldValue.increment(-1),
        if (wasReviewed) 'reviewedCount': FieldValue.increment(-1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> restartDeck(String userId, String deckId) async {
    final QuerySnapshot<Map<String, dynamic>> cardsSnapshot = await _cardCollection(
      userId,
      deckId,
    ).get();

    if (cardsSnapshot.docs.isNotEmpty) {
      for (int index = 0; index < cardsSnapshot.docs.length; index += 400) {
        final WriteBatch batch = _firestore.batch();
        final int end = math.min(index + 400, cardsSnapshot.docs.length);
        for (int i = index; i < end; i++) {
          batch.update(cardsSnapshot.docs[i].reference, <String, dynamic>{
            'isReviewed': false,
            'rememberedLastTime': null,
            'reviewedAt': null,
            'updatedAt': Timestamp.now(),
          });
        }
        await batch.commit();
      }
    }

    await _deckDoc(userId, deckId).set(<String, dynamic>{
      'reviewedCount': 0,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> markCardReviewed(
    String userId,
    String deckId,
    String cardId, {
    required bool remembered,
  }) async {
    final DocumentReference<Map<String, dynamic>> deckRef = _deckDoc(
      userId,
      deckId,
    );
    final DocumentReference<Map<String, dynamic>> cardRef = _cardCollection(
      userId,
      deckId,
    ).doc(cardId);

    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> cardSnapshot = await tx.get(
        cardRef,
      );
      if (!cardSnapshot.exists) return;

      final bool wasReviewed =
          (cardSnapshot.data()?['isReviewed'] as bool?) ?? false;

      tx.set(cardRef, <String, dynamic>{
        'isReviewed': true,
        'rememberedLastTime': remembered,
        'reviewedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (!wasReviewed) {
        tx.set(deckRef, <String, dynamic>{
          'reviewedCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Shuffle the cards for a given deck locally and notify listeners.
  /// This does not persist order to Firestore (cards order is derived from createdAt).
  /// The shuffle is local only to improve UX during a study session.
  void shuffleDeck(String deckId) {
    final FlashcardDeck? deck = _decks[deckId];
    if (deck == null) return;
    deck.cards.shuffle();
    // reset front index if necessary is handled by caller (UI)
    notifyListeners();
  }

  /// Replace the in-memory order of cards for the given deck and notify listeners.
  /// Use this for undoing a local shuffle. This does not persist changes to Firestore.
  void setDeckOrder(String deckId, List<FlashcardCard> cards) {
    final FlashcardDeck? deck = _decks[deckId];
    if (deck == null) return;
    deck.cards
      ..clear()
      ..addAll(cards);
    notifyListeners();
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
  FlashcardDeck({
    required this.id,
    required this.title,
    required this.cardCount,
    required this.reviewedCount,
    required this.updatedAt,
    List<FlashcardCard>? cards,
  }) : cards = cards ?? <FlashcardCard>[];

  factory FlashcardDeck.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FlashcardDeck.fromMap(doc.id, doc.data());
  }

  factory FlashcardDeck.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FlashcardDeck.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory FlashcardDeck.fromMap(String id, Map<String, dynamic> data) {
    return FlashcardDeck(
      id: id,
      title: _readString(data['title']) ?? 'Bộ từ vựng',
      cardCount: _readInt(data['cardCount']) ?? 0,
      reviewedCount: _readInt(data['reviewedCount']) ?? 0,
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  final String id;
  String title;
  int cardCount;
  int reviewedCount;
  DateTime? updatedAt;
  final List<FlashcardCard> cards;

  double get progress => cardCount <= 0 ? 0 : reviewedCount / cardCount;

  static String? _readString(dynamic value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class FlashcardCard {
  FlashcardCard({
    required this.id,
    required this.english,
    required this.meaning,
    required this.example,
    required this.isReviewed,
    required this.rememberedLastTime,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewedAt,
    this.audioUrl,
    this.phonetic,
  });

  factory FlashcardCard.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FlashcardCard.fromMap(doc.id, doc.data());
  }

  factory FlashcardCard.fromMap(String id, Map<String, dynamic> data) {
    return FlashcardCard(
      id: id,
      english: _readString(data['english']) ?? '',
      meaning: _readString(data['meaning']) ?? '',
      example: _readString(data['example']) ?? '',
      isReviewed: (data['isReviewed'] as bool?) ?? false,
      rememberedLastTime: data['rememberedLastTime'] as bool?,
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      reviewedAt: _readDateTime(data['reviewedAt']),
      audioUrl: _readString(data['audioUrl']),
      phonetic: _readString(data['phonetic']),
    );
  }

  final String id;
  final String english;
  final String meaning;
  final String example;
  final bool isReviewed;
  final bool? rememberedLastTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  /// URL to pronunciation audio (MP3). Nullable – may be absent for old cards.
  final String? audioUrl;

  /// IPA phonetic transcription e.g. "/həˈloʊ/". Nullable.
  final String? phonetic;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'english': english,
      'meaning': meaning,
      'example': example,
      'isReviewed': isReviewed,
      'rememberedLastTime': rememberedLastTime,
      'createdAt': createdAt == null
          ? Timestamp.now()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? Timestamp.now()
          : Timestamp.fromDate(updatedAt!),
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (phonetic != null) 'phonetic': phonetic,
    };
  }

  static String? _readString(dynamic value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/dictionary_service.dart';

/// Lightweight service that orchestrates:
///   DictionaryService.lookupWord  ──▶  Firestore write (card + deck counter)
///
/// Firestore schema (mirrors FlashcardProvider):
///   users/{userId}/flashcard_decks/{deckId}           ← deck doc (cardCount++)
///   users/{userId}/flashcard_decks/{deckId}/cards/{id} ← new card doc
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();
  factory FirestoreService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DictionaryService _dict = DictionaryService();

  // ── Path helpers ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _deckCol(String userId) =>
      _db.collection('users').doc(userId).collection('flashcard_decks');

  DocumentReference<Map<String, dynamic>> _deckDoc(
          String userId, String deckId) =>
      _deckCol(userId).doc(deckId);

  CollectionReference<Map<String, dynamic>> _cardCol(
          String userId, String deckId) =>
      _deckDoc(userId, deckId).collection('cards');

  // ── Public API ────────────────────────────────────────────────────────────

  /// Looks up [word] via the Free Dictionary API, maps the result to a
  /// Firestore card document, and atomically saves it + increments
  /// `cardCount` on the parent deck.
  ///
  /// Throws [WordNotFoundException] when the API returns 404.
  /// Throws [FirebaseException] or generic [Exception] for other errors.
  Future<void> saveWordToDeck({
    required String word,
    required String deckId,
    String? userId,
  }) async {
    final String uid = userId ?? _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) throw Exception('User not authenticated');
    if (word.trim().isEmpty) throw Exception('Word cannot be empty');
    if (deckId.isEmpty) throw Exception('Deck ID cannot be empty');

    // ── Step 1: Lookup dictionary ─────────────────────────────────────────
    // WordNotFoundException bubbles up if the API returns 404.
    final entry = await _dict.lookupWord(word);

    // ── Step 2: Build card payload ────────────────────────────────────────
    // Field names match FlashcardCard.fromMap() in flashcard_provider.dart.
    final cardData = <String, dynamic>{
      'english': entry.word.trim(),
      'meaning': entry.definition.trim().isEmpty
          ? '(no definition)'
          : entry.definition.trim(),
      'example': entry.partOfSpeech.isNotEmpty
          ? '(${entry.partOfSpeech})'  // store part-of-speech as fallback example
          : '',
      // Extra metadata visible in the card flip UI
      'phonetic': entry.phonetic,
      'audioUrl': entry.audioUrl,
      'isReviewed': false,
      'rememberedLastTime': null,
      'status': 'new',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'reviewedAt': null,
    };

    // ── Step 3 & 4: Atomic write – card + deck counter ──────────────────
    final cardRef = _cardCol(uid, deckId).doc();
    final deckRef = _deckDoc(uid, deckId);

    await _db.runTransaction((tx) async {
      tx.set(cardRef, cardData);
      tx.set(
        deckRef,
        <String, dynamic>{
          'cardCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
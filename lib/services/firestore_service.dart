import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/dictionary_service.dart';
import '../translation/translation_service.dart';
import '../models/dictionary_entry_model.dart';

/// Lightweight service that orchestrates:
///   DictionaryService.lookupWord  ──▶  Firestore write (card + deck counter)
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();
  factory FirestoreService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DictionaryService _dict = DictionaryService();
  final TranslationService _translator = TranslationService(
    endpoint: 'https://api.mymemory.translated.net/get',
  );

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

  Future<void> saveWordToDeck({
    required String word,
    required String deckId,
    String? userId,
    String? meaning,
  }) async {
    final String uid = userId ?? _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) throw Exception('User not authenticated');
    if (word.trim().isEmpty) throw Exception('Word cannot be empty');
    if (deckId.isEmpty) throw Exception('Deck ID cannot be empty');

    // ── Step 1: Lookup dictionary or use provided meaning ─────────────────────────────────────────
    late final DictionaryEntry entry;
    String finalMeaning;
    if (meaning != null && meaning.trim().isNotEmpty) {
      // Use provided meaning, create a minimal entry
      entry = DictionaryEntry(
        word: word.trim(),
        definition: meaning.trim(),
        phonetic: '',
        partOfSpeech: '',
        example: '',
        audioUrl: '',
      );
      finalMeaning = meaning.trim();
    } else {
      // Lookup dictionary
      entry = await _dict.lookupWord(word);
      finalMeaning = entry.definition.trim().isEmpty
          ? '(no definition)'
          : entry.definition.trim();
    }

    // ── Step 2: Handle Example & Translation ──────────────────────────────
    String finalExample = '';
    if (entry.example.isNotEmpty) {
      try {
        final transRes = await _translator.translate(
          selected: entry.example,
          context: '',
          target: 'vi',
        );
        finalExample = '${entry.example}\n(${transRes.translatedText})';
      } catch (e) {
        finalExample = entry.example; // Fallback to raw example if translation fails
      }
    } else {
      // Use part of speech as small hint if no example found
      finalExample = entry.partOfSpeech.isNotEmpty ? '(${entry.partOfSpeech})' : '';
    }

    // ── Step 3: Build card payload ────────────────────────────────────────
    final cardData = <String, dynamic>{
      'english': entry.word.trim(),
      'meaning': finalMeaning,
      'example': finalExample.trim(),
      'phonetic': entry.phonetic,
      'audioUrl': entry.audioUrl,
      'isReviewed': false,
      'rememberedLastTime': null,
      'status': 'new',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'reviewedAt': null,
    };

    // ── Step 4: Atomic write ─────────────────────────────────────────────
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

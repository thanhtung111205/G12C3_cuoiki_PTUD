import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardModel {
  final String id;
  final String deckId;
  final String userId;
  final String? sourceDocId;
  final String word;
  final String? phonetic;
  final String meaning;
  final String? example;
  final String? audioUrl;
  final String status;
  final DateTime? nextReviewDate;

  const FlashcardModel({
    required this.id,
    required this.deckId,
    required this.userId,
    this.sourceDocId,
    required this.word,
    this.phonetic,
    required this.meaning,
    this.example,
    this.audioUrl,
    required this.status,
    this.nextReviewDate,
  });

  FlashcardModel copyWith({
    String? id,
    String? deckId,
    String? userId,
    String? sourceDocId,
    String? word,
    String? phonetic,
    String? meaning,
    String? example,
    String? audioUrl,
    String? status,
    DateTime? nextReviewDate,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      userId: userId ?? this.userId,
      sourceDocId: sourceDocId ?? this.sourceDocId,
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      meaning: meaning ?? this.meaning,
      example: example ?? this.example,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  factory FlashcardModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FlashcardModel(
      id: documentId,
      deckId: map['deckId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      sourceDocId: map['sourceDocId'] as String?,
      word: map['word'] as String? ?? '',
      phonetic: map['phonetic'] as String?,
      meaning: map['meaning'] as String? ?? '',
      example: map['example'] as String?,
      audioUrl: map['audioUrl'] as String?,
      status: map['status'] as String? ?? 'new',
      nextReviewDate: (map['nextReviewDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'userId': userId,
      if (sourceDocId != null) 'sourceDocId': sourceDocId,
      'word': word,
      if (phonetic != null) 'phonetic': phonetic,
      'meaning': meaning,
      if (example != null) 'example': example,
      if (audioUrl != null) 'audioUrl': audioUrl,
      'status': status,
      if (nextReviewDate != null) 'nextReviewDate': Timestamp.fromDate(nextReviewDate!),
    };
  }
}
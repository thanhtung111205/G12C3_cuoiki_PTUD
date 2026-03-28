import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardDeckModel {
  final String id;
  final String userId;
  final String name;
  final int totalCards;
  final int reviewedCards;
  final DateTime createdAt;

  const FlashcardDeckModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.totalCards,
    required this.reviewedCards,
    required this.createdAt,
  });

  FlashcardDeckModel copyWith({
    String? id,
    String? userId,
    String? name,
    int? totalCards,
    int? reviewedCards,
    DateTime? createdAt,
  }) {
    return FlashcardDeckModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      totalCards: totalCards ?? this.totalCards,
      reviewedCards: reviewedCards ?? this.reviewedCards,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FlashcardDeckModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FlashcardDeckModel(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      totalCards: map['totalCards'] as int? ?? 0,
      reviewedCards: map['reviewedCards'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'totalCards': totalCards,
      'reviewedCards': reviewedCards,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
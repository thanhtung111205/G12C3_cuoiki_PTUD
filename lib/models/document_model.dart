import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final List<String> tags;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.tags,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
  });

  DocumentModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    List<String>? tags,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DocumentModel(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      wordCount: map['wordCount'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'tags': tags,
      'wordCount': wordCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
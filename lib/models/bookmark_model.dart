import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkModel {
  final String id;
  final String userId;
  final String articleId;
  final String title;
  final String source;
  final String url;
  final String? thumbnailUrl;
  final bool isSaved;
  final DateTime savedAt;

  const BookmarkModel({
    required this.id,
    required this.userId,
    required this.articleId,
    required this.title,
    required this.source,
    required this.url,
    this.thumbnailUrl,
    required this.isSaved,
    required this.savedAt,
  });

  BookmarkModel copyWith({
    String? id,
    String? userId,
    String? articleId,
    String? title,
    String? source,
    String? url,
    String? thumbnailUrl,
    bool? isSaved,
    DateTime? savedAt,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      source: source ?? this.source,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isSaved: isSaved ?? this.isSaved,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  factory BookmarkModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BookmarkModel(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      articleId: map['articleId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      source: map['source'] as String? ?? '',
      url: map['url'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      isSaved: map['isSaved'] as bool? ?? false,
      savedAt: (map['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'articleId': articleId,
      'title': title,
      'source': source,
      'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'isSaved': isSaved,
      'savedAt': Timestamp.fromDate(savedAt),
    };
  }
}
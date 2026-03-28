class Article {
  final String articleId;
  final String title;
  final String source;
  final String link;
  final DateTime pubDate;
  final String? imageUrl;
  final String? description;

  const Article({
    required this.articleId,
    required this.title,
    required this.source,
    required this.link,
    required this.pubDate,
    this.imageUrl,
    this.description,
  });

  Article copyWith({
    String? articleId,
    String? title,
    String? source,
    String? link,
    DateTime? pubDate,
    String? imageUrl,
    String? description,
  }) {
    return Article(
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      source: source ?? this.source,
      link: link ?? this.link,
      pubDate: pubDate ?? this.pubDate,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      articleId: map['articleId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      source: map['source'] as String? ?? '',
      link: map['link'] as String? ?? '',
      pubDate: map['pubDate'] != null
          ? DateTime.tryParse(map['pubDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      imageUrl: map['imageUrl'] as String?,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'articleId': articleId,
      'title': title,
      'source': source,
      'link': link,
      'pubDate': pubDate.toIso8601String(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (description != null) 'description': description,
    };
  }
}

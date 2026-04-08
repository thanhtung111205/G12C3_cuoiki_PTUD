import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/article_model.dart';
import '../models/bookmark_model.dart';
import '../services/news_storage_service.dart';
import '../services/rss_service.dart';

class NewsProvider extends ChangeNotifier {
  final RssService _rssService = RssService();
  final NewsStorageService _newsStorage = NewsStorageService.instance;

  List<Article> _allArticles = [];
  List<Article> _filteredArticles = [];
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _readIds = {};
  final Map<String, BookmarkModel> _bookmarks = {};

  StreamSubscription<Set<String>>? _readIdsSub;
  StreamSubscription<Map<String, BookmarkModel>>? _bookmarksSub;
  String? _currentUserId;

  List<Article> get articles => _filteredArticles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Set<String> get readIds => _readIds;
  Map<String, BookmarkModel> get bookmarks => _bookmarks;

  void syncForUser(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    _readIdsSub?.cancel();
    _bookmarksSub?.cancel();
    _readIds.clear();
    _bookmarks.clear();

    if (userId == null) {
      notifyListeners();
      return;
    }

    _readIdsSub = _newsStorage.getReadArticlesStream(userId).listen((ids) {
      _readIds.clear();
      _readIds.addAll(ids);
      notifyListeners();
    });

    _bookmarksSub = _newsStorage.getBookmarksStream(userId).listen((items) {
      _bookmarks.clear();
      _bookmarks.addAll(items);
      notifyListeners();
    });
  }

  Future<void> loadNews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final articles = await _rssService.fetchNews();
      _allArticles = articles;
      _filteredArticles = articles;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      _filteredArticles = _allArticles;
    } else {
      _filteredArticles = _allArticles
          .where((article) =>
              article.title.toLowerCase().contains(query.toLowerCase()) ||
              (article.description?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _filteredArticles = _allArticles;
    notifyListeners();
  }

  void markAsRead(Article article) {
    _readIds.add(article.articleId);
    notifyListeners();

    if (_currentUserId != null) {
      _newsStorage.markAsRead(_currentUserId!, article.articleId);
    }
  }

  void toggleBookmark(Article article) {
    if (_bookmarks.containsKey(article.articleId)) {
      _bookmarks.remove(article.articleId);
      if (_currentUserId != null) {
        _newsStorage.removeBookmark(_currentUserId!, article.articleId);
      }
    } else {
      final bmk = BookmarkModel(
        id: article.articleId,
        userId: _currentUserId ?? 'local_user',
        articleId: article.articleId,
        title: article.title,
        source: article.source,
        url: article.link,
        thumbnailUrl: article.imageUrl,
        isSaved: true,
        savedAt: DateTime.now(),
      );
      _bookmarks[article.articleId] = bmk;
      if (_currentUserId != null) {
        _newsStorage.addBookmark(_currentUserId!, bmk);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _readIdsSub?.cancel();
    _bookmarksSub?.cancel();
    super.dispose();
  }
}
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/article_model.dart';
import '../../models/bookmark_model.dart';
import '../../screens/news/article_detail_screen.dart';
import '../../services/news_storage_service.dart';
import '../../services/rss_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/article_card.dart';

// Global placeholder state (kept for compatibility with existing screens).
final Set<String> globalReadIds = <String>{};
final Map<String, BookmarkModel> globalBookmarks = <String, BookmarkModel>{};

class NewsTabsScreen extends StatefulWidget {
  const NewsTabsScreen({super.key});

  @override
  State<NewsTabsScreen> createState() => _NewsTabsScreenState();
}

class _NewsTabsScreenState extends State<NewsTabsScreen>
    with SingleTickerProviderStateMixin {
  final RssService _rssService = RssService();
  final NewsStorageService _newsStorage = NewsStorageService.instance;

  Future<List<Article>>? _newsFuture;
  StreamSubscription<Set<String>>? _readIdsSub;
  StreamSubscription<Map<String, BookmarkModel>>? _bookmarksSub;

  // Search logic
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Article> _allArticles = [];
  List<Article> _filteredArticles = [];

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadNews();
    _initFirestoreSync();
  }

  void _loadNews() {
    _newsFuture = _rssService.fetchNews().then((articles) {
      if (mounted) {
        setState(() {
          _allArticles = articles;
          _filteredArticles = articles;
        });
      }
      return articles;
    });
  }

  void _initFirestoreSync() {
    final String? uid = _userId;
    if (uid == null) return;

    _readIdsSub = _newsStorage.getReadArticlesStream(uid).listen((ids) {
      if (!mounted) return;
      setState(() {
        globalReadIds
          ..clear()
          ..addAll(ids);
      });
    });

    _bookmarksSub = _newsStorage.getBookmarksStream(uid).listen((items) {
      if (!mounted) return;
      setState(() {
        globalBookmarks
          ..clear()
          ..addAll(items);
      });
    });
  }

  @override
  void dispose() {
    _readIdsSub?.cancel();
    _bookmarksSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _markAsRead(Article article) {
    setState(() {
      globalReadIds.add(article.articleId);
    });

    final String? uid = _userId;
    if (uid != null) {
      _newsStorage.markAsRead(uid, article.articleId);
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ArticleDetailScreen(article: article),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  void _toggleBookmark(Article article) {
    final String? uid = _userId;

    setState(() {
      if (globalBookmarks.containsKey(article.articleId)) {
        globalBookmarks.remove(article.articleId);
        if (uid != null) {
          _newsStorage.removeBookmark(uid, article.articleId);
        }
      } else {
        final BookmarkModel bmk = BookmarkModel(
          id: article.articleId,
          userId: uid ?? 'local_user',
          articleId: article.articleId,
          title: article.title,
          source: article.source,
          url: article.link,
          thumbnailUrl: article.imageUrl,
          isSaved: true,
          savedAt: DateTime.now(),
        );
        globalBookmarks[article.articleId] = bmk;
        if (uid != null) {
          _newsStorage.addBookmark(uid, bmk);
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredArticles = _allArticles;
      } else {
        _filteredArticles = _allArticles
            .where((article) =>
                article.title.toLowerCase().contains(query.toLowerCase()) ||
                (article.description?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredArticles = _allArticles;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bgColor = isDark
        ? AppColors.darkBackground
        : const Color(0xFFF7F5FF);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(isDark),
        body: TabBarView(
          children: <Widget>[
            _NewsFeedTab(
              newsFuture: _newsFuture,
              articles: _filteredArticles,
              readIds: globalReadIds,
              bookmarks: globalBookmarks,
              onTap: _markAsRead,
              onBookmarkToggle: _toggleBookmark,
              onRefresh: () async {
                _loadNews();
              },
            ),
            _BookmarksTab(
              bookmarks: globalBookmarks,
              readIds: globalReadIds,
              onTap: _markAsRead,
              onBookmarkToggle: _toggleBookmark,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final Color surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return AppBar(
      backgroundColor: surfaceColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm tin tức...',
                border: InputBorder.none,
              ),
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 18,
              ),
              onChanged: _onSearchChanged,
            )
          : Text(
              'Đọc báo Tiếng Anh',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: _toggleSearch,
          ),
        ),
      ],
      bottom: TabBar(
        indicatorColor: AppColors.deepPurple,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.deepPurple,
        unselectedLabelColor: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: const <Tab>[
          Tab(text: 'Tin mới'),
          Tab(text: 'Đã lưu'),
        ],
      ),
    );
  }
}

class _NewsFeedTab extends StatelessWidget {
  const _NewsFeedTab({
    required this.newsFuture,
    required this.articles,
    required this.readIds,
    required this.bookmarks,
    required this.onTap,
    required this.onBookmarkToggle,
    required this.onRefresh,
  });

  final Future<List<Article>>? newsFuture;
  final List<Article> articles;
  final Set<String> readIds;
  final Map<String, BookmarkModel> bookmarks;
  final void Function(Article) onTap;
  final void Function(Article) onBookmarkToggle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (newsFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<Article>>(
      future: newsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Article>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && articles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && articles.isEmpty) {
          return _ErrorView(message: snapshot.error.toString());
        }

        if (articles.isEmpty) {
          return const _EmptyView(
            icon: Icons.newspaper_rounded,
            message: 'Không có bài báo nào.\nVui lòng kiểm tra kết nối mạng.',
          );
        }

        return RefreshIndicator(
          color: AppColors.deepPurple,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            itemBuilder: (BuildContext context, int index) {
              final Article article = articles[index];
              return ArticleCard(
                article: article,
                isRead: readIds.contains(article.articleId),
                isBookmarked: bookmarks.containsKey(article.articleId),
                onTap: () => onTap(article),
                onBookmarkToggle: () => onBookmarkToggle(article),
              );
            },
          ),
        );
      },
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab({
    required this.bookmarks,
    required this.readIds,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  final Map<String, BookmarkModel> bookmarks;
  final Set<String> readIds;
  final void Function(Article) onTap;
  final void Function(Article) onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return const _EmptyView(
        icon: Icons.bookmark_border_rounded,
        message:
            'Chưa có bài báo nào được lưu.\nBấm bookmark để lưu bài yêu thích!',
      );
    }

    final List<Article> saved = bookmarks.values
        .map(
          (BookmarkModel b) => Article(
            articleId: b.articleId,
            title: b.title,
            source: b.source,
            link: b.url,
            pubDate: b.savedAt,
            imageUrl: b.thumbnailUrl,
          ),
        )
        .toList(growable: false);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: saved.length,
      itemBuilder: (BuildContext context, int index) {
        final Article article = saved[index];
        return ArticleCard(
          article: article,
          isRead: readIds.contains(article.articleId),
          isBookmarked: true,
          onTap: () => onTap(article),
          onBookmarkToggle: () => onBookmarkToggle(article),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: AppColors.periwinkle,
            ),
            const SizedBox(height: 16),
            Text(
              'Không tải được tin tức',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: AppColors.periwinkle),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

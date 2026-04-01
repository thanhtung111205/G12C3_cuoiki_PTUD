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

  late final Future<List<Article>> _newsFuture;
  StreamSubscription<Set<String>>? _readIdsSub;
  StreamSubscription<Map<String, BookmarkModel>>? _bookmarksSub;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _newsFuture = _rssService.fetchNews();
    _initFirestoreSync();
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
        appBar: _NewsAppBar(isDark: isDark),
        body: TabBarView(
          children: <Widget>[
            _NewsFeedTab(
              newsFuture: _newsFuture,
              readIds: globalReadIds,
              bookmarks: globalBookmarks,
              onTap: _markAsRead,
              onBookmarkToggle: _toggleBookmark,
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
}

class _NewsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NewsAppBar({required this.isDark});

  final bool isDark;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return AppBar(
      backgroundColor: surfaceColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Doc bao Tieng Anh',
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
              Icons.search_rounded,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () => print('Navigate to SearchScreen'),
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
          Tab(text: 'Tin moi'),
          Tab(text: 'Da luu'),
        ],
      ),
    );
  }
}

class _NewsFeedTab extends StatelessWidget {
  const _NewsFeedTab({
    required this.newsFuture,
    required this.readIds,
    required this.bookmarks,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  final Future<List<Article>> newsFuture;
  final Set<String> readIds;
  final Map<String, BookmarkModel> bookmarks;
  final void Function(Article) onTap;
  final void Function(Article) onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Article>>(
      future: newsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Article>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorView(message: snapshot.error.toString());
        }

        final List<Article> articles = snapshot.data ?? <Article>[];
        if (articles.isEmpty) {
          return const _EmptyView(
            icon: Icons.newspaper_rounded,
            message: 'Khong co bai bao nao.\nVui long kiem tra ket noi mang.',
          );
        }

        return RefreshIndicator(
          color: AppColors.deepPurple,
          onRefresh: () async {
            print('Refresh news feed');
          },
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
            'Chua co bai bao nao duoc luu.\nBam bookmark de luu bai yeu thich!',
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
              'Khong tai duoc tin tuc',
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

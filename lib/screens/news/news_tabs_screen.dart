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

/// A two-tab screen:
///   Tab 0 – "Tin mới"  : live RSS feed loaded with FutureBuilder.
///   Tab 1 – "Đã lưu"   : list of locally-bookmarked articles.
///
/// State is managed locally (no external state manager) for UI demo purposes.
/// Read history and bookmarks are stored as in-memory Sets/Maps and will be
/// replaced by Firestore-backed services in the next iteration.

// ── Global State (Placeholder for Firestore) ──────────────────────────────
final Set<String> globalReadIds = {};
final Map<String, BookmarkModel> globalBookmarks = {};

class NewsTabsScreen extends StatefulWidget {
  const NewsTabsScreen({super.key});

  @override
  State<NewsTabsScreen> createState() => _NewsTabsScreenState();
}

class _NewsTabsScreenState extends State<NewsTabsScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  final RssService _rssService = RssService();
  final NewsStorageService _newsStorage = NewsStorageService.instance;

  // ── Future & Streams ─────────────────────────────────────────────────────────────
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
    final uid = _userId;
    if (uid == null) return;

    _readIdsSub = _newsStorage.getReadArticlesStream(uid).listen((ids) {
      if (mounted) {
        setState(() {
          globalReadIds
            ..clear()
            ..addAll(ids);
        });
      }
    });

    _bookmarksSub = _newsStorage.getBookmarksStream(uid).listen((bms) {
      if (mounted) {
        setState(() {
          globalBookmarks
            ..clear()
            ..addAll(bms);
        });
      }
    });
  }

  @override
  void dispose() {
    _readIdsSub?.cancel();
    _bookmarksSub?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _markAsRead(Article article) {
    // Attempt local optimistic update for snappiness
    setState(() {
      globalReadIds.add(article.articleId);
    });
    if (_userId != null) {
      _newsStorage.markAsRead(_userId!, article.articleId);
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ArticleDetailScreen(article: article),
          ),
        )
        .then((_) {
          // Refresh list to update bookmark icons if changed inside the detail screen
          if (mounted) setState(() {});
        });
  }

  void _toggleBookmark(Article article) {
    final uid = _userId;
    
    setState(() {
      if (globalBookmarks.containsKey(article.articleId)) {
        globalBookmarks.remove(article.articleId);
        if (uid != null) {
          _newsStorage.removeBookmark(uid, article.articleId);
        }
      } else {
        final bmk = BookmarkModel(
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

  // ── Build ─────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR  (contains the styled TabBar)
// ─────────────────────────────────────────────────────────────────────────────

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
        'Đọc báo Tiếng Anh',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      // Search action – placeholder for future feature.
      actions: [
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
          Tab(text: 'Tin mới'),
          Tab(text: 'Đã lưu'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 – NEWS FEED
// ─────────────────────────────────────────────────────────────────────────────

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
      builder: (context, snapshot) {
        // ── Loading ──────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        // ── Error ────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return _ErrorView(message: snapshot.error.toString());
        }

        // ── Empty ────────────────────────────────────────────────────────
        final List<Article> articles = snapshot.data ?? [];
        if (articles.isEmpty) {
          return const _EmptyView(
            icon: Icons.newspaper_rounded,
            message: 'Không có bài báo nào.\nVui lòng kiểm tra kết nối mạng.',
          );
        }

        // ── Article list ─────────────────────────────────────────────────
        return RefreshIndicator(
          color: AppColors.deepPurple,
          onRefresh: () async {
            // In a real app, invalidate the cache and re-fetch here.
            print('Refresh news feed');
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            itemBuilder: (context, index) {
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 – BOOKMARKS
// ─────────────────────────────────────────────────────────────────────────────

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
        message: 'Chưa có bài báo nào được lưu.\nBấm 🔖 để lưu bài yêu thích!',
      );
    }

    // Reconstruct lightweight Article objects from BookmarkModel data
    // so we can reuse the ArticleCard widget without code duplication.
    final List<Article> saved = bookmarks.values
        .map(
          (b) => Article(
            articleId: b.articleId,
            title: b.title,
            source: b.source,
            link: b.url,
            pubDate: b.savedAt,
            imageUrl: b.thumbnailUrl,
          ),
        )
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: saved.length,
      itemBuilder: (context, index) {
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

// ─────────────────────────────────────────────────────────────────────────────
// Utility views
// ─────────────────────────────────────────────────────────────────────────────

/// Animated placeholder cards shown while the RSS future resolves.
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, v) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: 6,
          itemBuilder: (ctx, i) =>
              _ShimmerCard(opacity: _anim.value, isDark: isDark),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.opacity, required this.isDark});

  final double opacity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color base = isDark
        ? Colors.white.withValues(alpha: opacity * 0.15)
        : Colors.black.withValues(alpha: opacity * 0.08);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

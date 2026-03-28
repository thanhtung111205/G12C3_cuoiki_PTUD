// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import '../models/article_model.dart';
import '../utils/app_colors.dart';

/// A single article row shown inside the News feed list.
///
/// Visual states:
/// - **Normal**   : full opacity, bookmark icon outlined.
/// - **Read**     : whole card faded to 50 % opacity to signal "already seen".
/// - **Bookmarked**: bookmark icon filled, tinted Deep Purple.
class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    required this.isRead,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  final Article article;

  /// Whether the user has already opened this article.
  final bool isRead;

  /// Whether the article is saved to the bookmark list.
  final bool isBookmarked;

  /// Called when the card body is tapped.
  final VoidCallback onTap;

  /// Called when the bookmark icon is tapped.
  final VoidCallback onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      // Fade read articles to 50 % so unread ones stand out.
      opacity: isRead ? 0.50 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.deepPurple.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Thumbnail ───────────────────────────────────────────────
              _Thumbnail(imageUrl: article.imageUrl),

              const SizedBox(width: 12),

              // ── Text content ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Source tag
                    _SourceTag(
                      source: article.source,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Publish date
                    Text(
                      _formatDate(article.pubDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bookmark action ─────────────────────────────────────────
              _BookmarkButton(
                isBookmarked: isBookmarked,
                onTap: onBookmarkToggle,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 86,
        height: 86,
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _placeholder(),
                errorBuilder: (_, _e, _s) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.lavender,
      child: const Center(
        child: Icon(
          Icons.image_rounded,
          color: AppColors.periwinkle,
          size: 30,
        ),
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source, required this.isDark});

  final String source;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.deepPurple.withValues(alpha: 0.35)
            : AppColors.lavender,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        source,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.periwinkle : AppColors.deepPurple,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({
    required this.isBookmarked,
    required this.onTap,
    required this.isDark,
  });

  final bool isBookmarked;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 2),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: child,
          ),
          child: Icon(
            isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            key: ValueKey<bool>(isBookmarked),
            size: 22,
            color: isBookmarked
                ? AppColors.deepPurple
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
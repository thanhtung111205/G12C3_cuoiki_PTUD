import 'dart:convert';

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../../../models/article_model.dart';
import '../../../services/rss_service.dart';
import '../../../utils/app_colors.dart';
import '../data/home_mock_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME HEADER SECTION
// ─────────────────────────────────────────────────────────────────────────────

class HomeHeaderSection extends StatelessWidget {
  const HomeHeaderSection({
    super.key,
    required this.userName,
    required this.avatarUrl,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final String userName;
  final String? avatarUrl;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode;
    final Color bgColor = dark ? AppColors.darkHeader : AppColors.lavender;
    final Color textPrimary = dark ? AppColors.darkText : AppColors.lightText;
    final Color textSecondary = dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Xin chào 👋',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 24,
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Theme toggle button
          _ThemeToggleButton(isDarkMode: isDarkMode, onToggle: onToggleTheme),

          const SizedBox(width: 10),

          // Avatar
          _UserAvatar(avatarUrl: avatarUrl),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.isDarkMode, required this.onToggle});

  final bool isDarkMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.deepPurple.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepPurple.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            key: ValueKey<bool>(isDarkMode),
            size: 22,
            color: isDarkMode ? const Color(0xFFFFD54F) : AppColors.deepPurple,
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.avatarUrl});

  final String? avatarUrl;

  bool get _isDataUri => avatarUrl?.startsWith('data:image/') == true;

  Widget _fallback() {
    return Container(
      color: AppColors.lavender,
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.deepPurple,
        size: 26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;

    if (_isDataUri) {
      final String base64Data = avatarUrl!.split(',').last;
      child = Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      child = Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      child = _fallback();
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.deepPurple, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepPurple.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOT NEWS CAROUSEL
// ─────────────────────────────────────────────────────────────────────────────

class HotNewsCarousel extends StatefulWidget {
  const HotNewsCarousel({super.key, required this.onTap});

  final void Function(Article article) onTap;

  @override
  State<HotNewsCarousel> createState() => _HotNewsCarouselState();
}

class _HotNewsCarouselState extends State<HotNewsCarousel> {
  final RssService _rssService = RssService();
  late Future<List<Article>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = _rssService.fetchArticles();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: FutureBuilder<List<Article>>(
        future: _articlesFuture,
        builder: (context, snapshot) {
          final List<Article> articles;

          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show shimmer-like loading cards
            articles = HomeMockData.fallbackArticles;
          } else if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            articles = HomeMockData.fallbackArticles;
          } else {
            articles = snapshot.data!.take(5).toList();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: articles.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < articles.length - 1 ? 14 : 0,
                ),
                child: _ArticleCard(
                  article: articles[index],
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                  onTap: () => widget.onTap(articles[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.onTap,
    this.isLoading = false,
  });

  final Article article;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Background image
            _ArticleImage(imageUrl: article.imageUrl, isLoading: isLoading),

            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x55000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.35, 0.65, 1.0],
                ),
              ),
            ),

            // Text content
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepPurple.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      article.source,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.imageUrl, this.isLoading = false});

  final String? imageUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          return progress == null ? child : _placeholder();
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.darkSurface,
      child: const Center(
        child: Icon(Icons.image_rounded, color: Colors.white24, size: 48),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────────────────────────────────────

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    this.horizontalPadding = 20,
  });

  final String title;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.deepPurple,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN FEATURE GRID
// ─────────────────────────────────────────────────────────────────────────────

class MainFeatureGrid extends StatelessWidget {
  const MainFeatureGrid({
    super.key,
    required this.features,
    required this.onTap,
    required this.isDarkMode,
  });

  final List<CoreFeature> features;
  final void Function(CoreFeature feature) onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        return _FeatureTile(
          feature: features[index],
          isDarkMode: isDarkMode,
          onTap: () => onTap(features[index]),
        );
      },
    );
  }
}

class _FeatureTile extends StatefulWidget {
  const _FeatureTile({
    required this.feature,
    required this.isDarkMode,
    required this.onTap,
  });

  final CoreFeature feature;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.isDarkMode
        ? widget.feature.darkBg
        : widget.feature.lightBg;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: !widget.isDarkMode
                ? [
                    BoxShadow(
                      color: widget.feature.iconColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.feature.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.feature.icon,
                  color: widget.feature.iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  widget.feature.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: widget.isDarkMode
                        ? AppColors.darkText
                        : AppColors.lightText,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

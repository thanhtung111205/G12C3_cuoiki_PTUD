// ignore_for_file: avoid_print

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../models/article_model.dart';
import '../../services/dictionary_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/dictionary_popup_overlay.dart';
import '../../widgets/smart_save_bottom_sheet.dart';
import '../../translation/context_translation_widget.dart';
import '../../translation/translation_service.dart';
import '../../translation/translation_viewmodel.dart';
import '../../models/bookmark_model.dart';
import '../../services/news_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'news_tabs_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  // ── Services ─────────────────────────────────────────────────────────────
  final DictionaryService _dictionaryService = DictionaryService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Local state ───────────────────────────────────────────────────────────
  late bool _isBookmarked;
  String _currentLookupWord = '';

  @override
  void initState() {
    super.initState();
    _isBookmarked = globalBookmarks.containsKey(widget.article.articleId);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _bodyText => (widget.article.description?.isNotEmpty ?? false)
      ? widget.article.description!
      : widget.article.title;

  String _formatDate(DateTime dt) {
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}'
        '  ·  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Selection → Dictionary ────────────────────────────────────────────────

  void _onSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    if (selection.start < 0 || selection.end <= selection.start) return;

    final String selectedText = _bodyText.substring(
      selection.start,
      selection.end,
    );

    // Strip punctuation; keep only word characters
    final String word = selectedText.replaceAll(RegExp(r'[^\w]'), '').trim();

    if (word.isNotEmpty && !word.contains(' ') && word != _currentLookupWord) {
      _currentLookupWord = word;
      print('Đã bôi đen từ: $word');
      _showDictionaryPopup(word);
    }
  }

  void _showDictionaryPopup(String selectedText) {
    _lookupWord(selectedText);
  }

  Future<void> _lookupWord(String word) async {
    if (!mounted) return;

    await showDictionaryPopupOverlay(
      context: context,
      word: word,
      dictionaryService: _dictionaryService,
      audioPlayer: _audioPlayer,
      onSave: (BuildContext sheetContext, entry) {
        Navigator.pop(sheetContext);
        showSmartSaveBottomSheet(context, word: entry.word);
      },
      onLookupError: () => _currentLookupWord = '',
      onClosed: () => _currentLookupWord = '',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color textSecondary = isDark
        ? const Color(0xFFAAAAAA)
        : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: bgColor,
      // ── App Bar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Bookmark toggle
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                key: ValueKey<bool>(_isBookmarked),
                color: _isBookmarked ? AppColors.deepPurple : textSecondary,
                size: 24,
              ),
            ),
            onPressed: () {
              setState(() {
                _isBookmarked = !_isBookmarked;
                final uid = FirebaseAuth.instance.currentUser?.uid;
                
                if (_isBookmarked) {
                  final bmk = BookmarkModel(
                    id: widget.article.articleId,
                    userId: uid ?? 'local_user',
                    articleId: widget.article.articleId,
                    title: widget.article.title,
                    source: widget.article.source,
                    url: widget.article.link,
                    thumbnailUrl: widget.article.imageUrl,
                    isSaved: true,
                    savedAt: DateTime.now(),
                  );
                  globalBookmarks[widget.article.articleId] = bmk;
                  if (uid != null) {
                    NewsStorageService.instance.addBookmark(uid, bmk);
                  }
                } else {
                  globalBookmarks.remove(widget.article.articleId);
                  if (uid != null) {
                    NewsStorageService.instance.removeBookmark(uid, widget.article.articleId);
                  }
                }
              });
              print(
                _isBookmarked
                    ? 'Bookmark: ${widget.article.articleId}'
                    : 'Remove bookmark: ${widget.article.articleId}',
              );
            },
          ),
          // Open in browser (placeholder)
          IconButton(
            icon: Icon(
              Icons.open_in_browser_rounded,
              color: textSecondary,
              size: 22,
            ),
            onPressed: () => print('Open URL: ${widget.article.link}'),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body ──────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Cover image ─────────────────────────────────────────────
            _CoverImage(imageUrl: widget.article.imageUrl),

            const SizedBox(height: 20),

            // ── Metadata block ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Source tag
                  _SourceTag(source: widget.article.source, isDark: isDark),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    widget.article.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      height: 1.35,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Date
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(widget.article.pubDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      thickness: 1,
                    ),
                  ),

                  // Tip banner
                  _HighlightTipBanner(isDark: isDark),

                  const SizedBox(height: 20),

                  // ── Article body with context-aware translation on selection ──
                  ContextTranslationWidget(
                    text: _bodyText,
                    viewModel: TranslationViewModel(
                      service: TranslationService(endpoint: 'https://api.mymemory.translated.net/get'),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Full-width cover image at the top with soft bottom radius.
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _placeholder(),
                errorBuilder: (_, e, s) => _placeholder(),
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
          Icons.image_not_supported_rounded,
          size: 48,
          color: AppColors.periwinkle,
        ),
      ),
    );
  }
}

/// Lavender-tinted source tag (Màu 3 – Tertiary).
class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source, required this.isDark});

  final String source;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.deepPurple.withValues(alpha: 0.30)
            : AppColors.lavender,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.newspaper_rounded,
            size: 13,
            color: isDark ? AppColors.periwinkle : AppColors.deepPurple,
          ),
          const SizedBox(width: 5),
          Text(
            source,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.periwinkle : AppColors.deepPurple,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small informational banner reminding users they can tap a word to translate.
class _HighlightTipBanner extends StatelessWidget {
  const _HighlightTipBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.deepPurple.withValues(alpha: 0.18)
            : AppColors.lavender.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.periwinkle.withValues(alpha: 0.25)
              : AppColors.deepPurple.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.touch_app_rounded,
            size: 16,
            color: isDark ? AppColors.periwinkle : AppColors.deepPurple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bôi đen một từ để tra nghĩa ngay lập tức ✨',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.periwinkle : AppColors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

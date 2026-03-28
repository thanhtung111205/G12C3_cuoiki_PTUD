// ignore_for_file: avoid_print

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../models/article_model.dart';
import '../../models/dictionary_entry_model.dart';
import '../../services/dictionary_service.dart';
import '../../utils/app_colors.dart';

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
  bool _isBookmarked = false;
  String _currentLookupWord = '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _bodyText =>
      (widget.article.description?.isNotEmpty ?? false)
          ? widget.article.description!
          : widget.article.title;

  String _formatDate(DateTime dt) {
    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

    final String selectedText =
        _bodyText.substring(selection.start, selection.end);

    // Strip punctuation; keep only word characters
    final String word =
        selectedText.replaceAll(RegExp(r'[^\w]'), '').trim();

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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          child: FutureBuilder<DictionaryEntry>(
            future: _dictionaryService.lookupWord(word),
            builder: (ctx, snapshot) {
              // ── Loading ───────────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _BottomSheetShell(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.deepPurple,
                      ),
                    ),
                  ),
                );
              }

              // ── Error ─────────────────────────────────────────────────
              if (snapshot.hasError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(sheetCtx)) Navigator.pop(sheetCtx);
                  final bool notFound =
                      snapshot.error is WordNotFoundException ||
                      snapshot.error.toString().contains('WordNotFoundException');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        notFound
                            ? 'Không tìm thấy nghĩa của "$word"'
                            : 'Lỗi tra từ điển: ${snapshot.error}',
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  _currentLookupWord = '';
                });
                return const SizedBox.shrink();
              }

              if (!snapshot.hasData) return const SizedBox.shrink();

              // ── Result ────────────────────────────────────────────────
              return _DictionaryResultSheet(
                entry: snapshot.data!,
                audioPlayer: _audioPlayer,
                onSave: () {
                  Navigator.pop(sheetCtx);
                  print('Lưu từ "${snapshot.data!.word}" vào Flashcard');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Đã lưu "${snapshot.data!.word}" vào Sổ từ'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() => _currentLookupWord = '');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color textSecondary =
        isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

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
              setState(() => _isBookmarked = !_isBookmarked);
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
            onPressed: () =>
                print('Open URL: ${widget.article.link}'),
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

                  // ── Article body (SelectableText) ───────────────────────
                  SelectableText(
                    _bodyText,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.85,
                      color: textPrimary,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                    onSelectionChanged: _onSelectionChanged,
                    selectionControls: materialTextSelectionControls,
                    cursorColor: AppColors.deepPurple,
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

// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

/// Shell container for the bottom sheet – handles the rounded top corners,
/// drag handle, and keyboard inset padding.
class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Full dictionary result UI inside the bottom sheet.
class _DictionaryResultSheet extends StatelessWidget {
  const _DictionaryResultSheet({
    required this.entry,
    required this.audioPlayer,
    required this.onSave,
  });

  final DictionaryEntry entry;
  final AudioPlayer audioPlayer;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return _BottomSheetShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Word + audio ─────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.word,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (entry.audioUrl.isNotEmpty)
                  _AudioButton(audioUrl: entry.audioUrl, player: audioPlayer),
              ],
            ),

            // ── Phonetic ─────────────────────────────────────────────────
            if (entry.phonetic.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                entry.phonetic,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.periwinkle,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Part of speech tag ────────────────────────────────────────
            if (entry.partOfSpeech.isNotEmpty) ...<Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.deepPurple.withValues(alpha: 0.3)
                      : AppColors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.partOfSpeech,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppColors.periwinkle : AppColors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Definition ───────────────────────────────────────────────
            if (entry.definition.isNotEmpty)
              Text(
                entry.definition,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),

            const SizedBox(height: 24),

            // ── Save to flashcard CTA ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: const Text('Lưu vào Sổ từ / Flashcard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular play button for pronunciation audio.
class _AudioButton extends StatefulWidget {
  const _AudioButton({required this.audioUrl, required this.player});

  final String audioUrl;
  final AudioPlayer player;

  @override
  State<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<_AudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    _ctrl.forward().then((_) => _ctrl.reverse());
    try {
      await widget.player.play(UrlSource(widget.audioUrl));
    } catch (e) {
      debugPrint('Audio error: $e');
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      ),
      child: GestureDetector(
        onTap: _play,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.deepPurple.withValues(alpha: 0.12),
          ),
          child: Icon(
            _playing ? Icons.volume_up_rounded : Icons.play_circle_rounded,
            color: AppColors.deepPurple,
            size: 24,
          ),
        ),
      ),
    );
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';

import '../providers/flashcard_provider.dart';
import '../utils/app_colors.dart';
import '../services/dictionary_service.dart';
import '../translation/translation_service.dart';

class FlashcardItemCard extends StatelessWidget {
  const FlashcardItemCard({super.key, required this.card});

  final FlashcardCard card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FlipCard(
        key: ValueKey(
          'flip_${card.id}',
        ), // Thêm key để reset trạng thái khi tráo thẻ
        flipOnTouch: true,
        direction: FlipDirection.HORIZONTAL,
        front: _FlashcardFrontFace(card: card),
        back: _FlashcardBackFace(card: card),
      ),
    );
  }
}

class _FlashcardFrontFace extends StatefulWidget {
  const _FlashcardFrontFace({required this.card});
  final FlashcardCard card;

  @override
  State<_FlashcardFrontFace> createState() => _FlashcardFrontFaceState();
}

class _FlashcardFrontFaceState extends State<_FlashcardFrontFace> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    final String? url = widget.card.audioUrl;
    if (url == null || url.isEmpty || _playing) return;
    setState(() => _playing = true);
    try {
      await _audioPlayer.play(UrlSource(url));
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playing = false);
      }).ignore();
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryText = isDark
        ? AppColors.darkText
        : AppColors.deepPurple;
    final Color secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color accent = theme.colorScheme.primary;
    final Color softAccent = isDark ? AppColors.darkCard : AppColors.lavender;

    final bool hasAudio =
        widget.card.audioUrl != null && widget.card.audioUrl!.isNotEmpty;

    return _CardSurface(
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: softAccent.withOpacity(0.85),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: hasAudio ? _playAudio : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasAudio
                      ? (_playing
                            ? accent.withOpacity(0.18)
                            : softAccent.withOpacity(0.7))
                      : (isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.grey.withOpacity(0.10)),
                  border: Border.all(
                    color: hasAudio
                        ? accent.withOpacity(0.40)
                        : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.18)),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _playing ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                  size: 22,
                  color: hasAudio ? accent : secondaryText.withOpacity(0.45),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.card.english,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: primaryText,
                          ),
                        ),
                        if (widget.card.phonetic != null &&
                            widget.card.phonetic!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.card.phonetic!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: accent,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chạm để lật thẻ',
                  style: TextStyle(
                    color: secondaryText.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: softAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Vuốt trái / phải để chấm điểm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
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

class _FlashcardBackFace extends StatefulWidget {
  const _FlashcardBackFace({required this.card});
  final FlashcardCard card;

  @override
  State<_FlashcardBackFace> createState() => _FlashcardBackFaceState();
}

class _FlashcardBackFaceState extends State<_FlashcardBackFace> {
  final DictionaryService _dict = DictionaryService();
  final TranslationService _translator = TranslationService(
    endpoint: 'https://api.mymemory.translated.net/get',
  );

  String? _smartExample;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAndFetchExample();
  }

  @override
  void didUpdateWidget(_FlashcardBackFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _smartExample = null; // Xóa ví dụ cũ khi thẻ thay đổi
      _checkAndFetchExample();
    }
  }

  String _sanitizeExample(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return '';
    final RegExp posOnly = RegExp(
      r'^\(\s*(noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection|determiner|article|auxiliary|modal|phrasal\s+verb|n|v|adj|adv|prep|conj|pron|det|interj)\s*\)\.?$',
      caseSensitive: false,
    );
    if (posOnly.hasMatch(text)) return '';
    return text;
  }

  Future<void> _checkAndFetchExample() async {
    final currentExample = _sanitizeExample(widget.card.example);
    if (currentExample.contains('I use') || currentExample.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      try {
        final entry = await _dict.lookupWord(widget.card.english);
        if (entry.example.isNotEmpty) {
          final transRes = await _translator.translate(
            selected: entry.example,
            context: '',
            target: 'vi',
          );
          if (mounted) {
            setState(() {
              _smartExample = '${entry.example}\n(${transRes.translatedText})';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = theme.colorScheme.primary;
    final Color primaryText = isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final String displayExample = _sanitizeExample(
      _smartExample ?? widget.card.example,
    );
    final bool hasExample =
        displayExample.isNotEmpty && !displayExample.contains('I use');

    return _CardSurface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lavender,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Mặt sau',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
             ),
             const SizedBox(height: 22),
             Expanded(
               child: SingleChildScrollView(
                 child: Text(
                   widget.card.meaning,
                   style: TextStyle(
                     fontSize: 28,
                     fontWeight: FontWeight.w900,
                     color: primaryText,
                   ),
                 ),
               ),
             ),
             const SizedBox(height: 18),
            Text(
              'Câu ví dụ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: secondaryText,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      ),
                    )
                  : (hasExample
                        ? SingleChildScrollView(
                            child: _HighlightedSentence(
                              sentence: displayExample,
                              targetWord: widget.card.english,
                            ),
                          )
                        : Center(
                            child: Text(
                              'Chưa có câu ví dụ.',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 15,
                              ),
                            ),
                          )),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedSentence extends StatelessWidget {
  const _HighlightedSentence({
    required this.sentence,
    required this.targetWord,
  });
  final String sentence;
  final String targetWord;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryText = isDark ? AppColors.darkText : AppColors.lightText;
    final Color accent = theme.colorScheme.primary;

    final RegExp pattern = RegExp(
      RegExp.escape(targetWord),
      caseSensitive: false,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;

    for (final Match match in pattern.allMatches(sentence)) {
      if (match.start > cursor)
        spans.add(TextSpan(text: sentence.substring(cursor, match.start)));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lavender,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              sentence.substring(match.start, match.end),
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < sentence.length)
      spans.add(TextSpan(text: sentence.substring(cursor)));

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: primaryText,
          fontSize: 18,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
        children: spans,
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? AppColors.darkCard : Colors.white;
    final Color border = isDark
        ? Colors.white.withOpacity(0.08)
        : AppColors.lavender;
    final Color shadow = isDark
        ? Colors.black.withOpacity(0.32)
        : AppColors.deepPurple.withOpacity(0.12);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(color: shadow, blurRadius: 26, offset: const Offset(0, 14)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
    );
  }
}

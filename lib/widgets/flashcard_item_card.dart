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
        key: ValueKey('flip_${card.id}'), // Thêm key để reset trạng thái khi tráo thẻ
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
    final bool hasAudio = widget.card.audioUrl != null && widget.card.audioUrl!.isNotEmpty;

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
                color: AppColors.lavender.withOpacity(0.85),
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
                      ? (_playing ? AppColors.deepPurple.withOpacity(0.18) : AppColors.pastelPink)
                      : Colors.grey.withOpacity(0.10),
                  border: Border.all(
                    color: hasAudio ? AppColors.periwinkle.withOpacity(0.40) : Colors.grey.withOpacity(0.18),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _playing ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                  size: 22,
                  color: hasAudio ? AppColors.deepPurple : Colors.grey.withOpacity(0.35),
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
                Text(
                  widget.card.english,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.05, color: AppColors.deepPurple),
                ),
                if (widget.card.phonetic != null && widget.card.phonetic!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(widget.card.phonetic!, style: const TextStyle(fontSize: 16, color: AppColors.periwinkle, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 12),
                Text('Chạm để lật thẻ', style: TextStyle(color: AppColors.lightTextSecondary.withOpacity(0.75), fontWeight: FontWeight.w500, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Vuốt trái / phải để chấm điểm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepPurple)),
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
  final TranslationService _translator = TranslationService(endpoint: 'https://api.mymemory.translated.net/get');
  
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

  Future<void> _checkAndFetchExample() async {
    final currentExample = widget.card.example;
    if (currentExample.contains('I use') || currentExample.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      try {
        final entry = await _dict.lookupWord(widget.card.english);
        if (entry.example.isNotEmpty) {
          final transRes = await _translator.translate(selected: entry.example, context: '', target: 'vi');
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
    final String displayExample = _smartExample ?? widget.card.example;
    final bool hasExample = displayExample.isNotEmpty && !displayExample.contains('I use');

    return _CardSurface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(999)),
              child: const Text('Mặt sau', style: TextStyle(color: AppColors.deepPurple, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 22),
            Text(widget.card.meaning, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 18),
            const Text('Câu ví dụ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.lightTextSecondary, letterSpacing: 0.3)),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading 
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.periwinkle)))
                : (hasExample 
                    ? SingleChildScrollView(child: _HighlightedSentence(sentence: displayExample, targetWord: widget.card.english))
                    : const Center(child: Text('Chưa có câu ví dụ.', style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 15)))
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedSentence extends StatelessWidget {
  const _HighlightedSentence({required this.sentence, required this.targetWord});
  final String sentence;
  final String targetWord;

  @override
  Widget build(BuildContext context) {
    final RegExp pattern = RegExp(RegExp.escape(targetWord), caseSensitive: false);
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;

    for (final Match match in pattern.allMatches(sentence)) {
      if (match.start > cursor) spans.add(TextSpan(text: sentence.substring(cursor, match.start)));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(8)),
          child: Text(sentence.substring(match.start, match.end), style: const TextStyle(color: AppColors.deepPurple, fontWeight: FontWeight.w800)),
        ),
      ));
      cursor = match.end;
    }
    if (cursor < sentence.length) spans.add(TextSpan(text: sentence.substring(cursor)));

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.lightText, fontSize: 18, height: 1.6, fontWeight: FontWeight.w500),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.lavender),
        boxShadow: <BoxShadow>[
          BoxShadow(color: AppColors.deepPurple.withOpacity(0.12), blurRadius: 26, offset: const Offset(0, 14)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
    );
  }
}

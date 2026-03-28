import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../../providers/flashcard_provider.dart';
import '../../utils/app_colors.dart';

class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({super.key, this.deckId});

  final String? deckId;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  final FlashcardProvider _provider = FlashcardProvider.instance;
  final CardSwiperController _swiperController = CardSwiperController();

  late String _deckId;
  int _frontIndex = 0;

  @override
  void initState() {
    super.initState();
    _deckId = widget.deckId ?? _provider.activeDeck.id;
    _provider.setActiveDeck(_deckId);
  }

  FlashcardDeck get _deck =>
      _provider.deckById(_deckId) ?? _provider.activeDeck;

  FlashcardCard? _currentCard(FlashcardDeck deck) {
    if (deck.cards.isEmpty) return null;
    final int safeIndex = _frontIndex.clamp(0, deck.cards.length - 1);
    return deck.cards[safeIndex];
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final FlashcardDeck deck = _deck;
    if (previousIndex >= 0 && previousIndex < deck.cards.length) {
      final FlashcardCard card = deck.cards[previousIndex];
      _provider.markCardReviewed(
        deck.id,
        card.id,
        remembered: direction == CardSwiperDirection.right,
      );
    }

    if (mounted) {
      setState(() {
        _frontIndex = currentIndex ?? previousIndex;
      });
    }
    return true;
  }

  Future<void> _openCardEditor({FlashcardCard? card}) async {
    final FlashcardDeck deck = _deck;
    final FlashcardDraft? result = await showModalBottomSheet<FlashcardDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _FlashcardEditorSheet(
          title: card == null ? 'Thêm flashcard' : 'Chỉnh sửa flashcard',
          englishInitial: card?.english ?? '',
          meaningInitial: card?.meaning ?? '',
        );
      },
    );

    if (result == null) return;

    if (card == null) {
      _provider.addCard(
        deck.id,
        english: result.english,
        meaning: result.meaning,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm flashcard mới')));
      }
      return;
    }

    _provider.updateCard(
      deck.id,
      card.id,
      english: result.english,
      meaning: result.meaning,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật flashcard')));
    }
  }

  void _swipeLeft() {
    _swiperController.swipe(CardSwiperDirection.left);
  }

  void _swipeRight() {
    _swiperController.swipe(CardSwiperDirection.right);
  }

  void _deleteCurrentCard(FlashcardDeck deck, FlashcardCard card) {
    final int removedIndex = _frontIndex;
    final FlashcardCard removedCard = card;
    _provider.deleteCard(deck.id, removedCard.id);

    if (mounted) {
      setState(() {
        _frontIndex = deck.cards.isEmpty
            ? 0
            : removedIndex.clamp(0, deck.cards.length - 1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xoá flashcard'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: AppColors.periwinkle,
            onPressed: () {
              _provider.insertCardAt(deck.id, removedIndex, removedCard);
              if (mounted) {
                setState(() {
                  _frontIndex = removedIndex;
                });
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _provider,
      builder: (BuildContext context, Widget? child) {
        final FlashcardDeck deck =
            _provider.deckById(_deckId) ?? _provider.activeDeck;
        final FlashcardCard? currentCard = _currentCard(deck);
        final int totalCards = deck.cards.length;
        final int reviewedCards = deck.reviewedCount;
        final double progress = deck.progress;

        return Scaffold(
          backgroundColor: AppColors.pastelPink,
          appBar: AppBar(
            backgroundColor: AppColors.pastelPink,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              deck.title,
              style: const TextStyle(
                color: AppColors.deepPurple,
                fontWeight: FontWeight.w800,
              ),
            ),
            iconTheme: const IconThemeData(color: AppColors.deepPurple),
            actions: <Widget>[
              IconButton(
                onPressed: () => _openCardEditor(),
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Thêm flashcard',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.65),
                        color: AppColors.periwinkle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Đã ôn $reviewedCards/$totalCards',
                          style: const TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          totalCards == 0
                              ? '0%'
                              : '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: AppColors.deepPurple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[AppColors.pastelPink, AppColors.lavender],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: totalCards == 0
                  ? _EmptyStudyState(onAdd: () => _openCardEditor())
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Column(
                        children: <Widget>[
                          _StudyHeader(
                            reviewed: reviewedCards,
                            total: totalCards,
                            rememberedCount: deck.cards
                                .where(
                                  (FlashcardCard card) =>
                                      card.rememberedLastTime == true,
                                )
                                .length,
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 0.78,
                                child: CardSwiper(
                                  controller: _swiperController,
                                  cardsCount: deck.cards.length,
                                  isLoop: false,
                                  duration: const Duration(milliseconds: 340),
                                  threshold: 55,
                                  scale: 0.95,
                                  padding: EdgeInsets.zero,
                                  onSwipe: _onSwipe,
                                  onEnd: () {
                                    HapticFeedback.mediumImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Bạn đã đi đến thẻ cuối cùng.',
                                        ),
                                      ),
                                    );
                                  },
                                  cardBuilder:
                                      (
                                        BuildContext context,
                                        int index,
                                        int horizontalOffsetPercentage,
                                        int verticalOffsetPercentage,
                                      ) {
                                        final FlashcardCard card =
                                            deck.cards[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: FlipCard(
                                            flipOnTouch: true,
                                            direction: FlipDirection.HORIZONTAL,
                                            front: _FlashcardFrontFace(
                                              card: card,
                                            ),
                                            back: _FlashcardBackFace(
                                              card: card,
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (currentCard != null)
                            _ActionRow(
                              onDelete: () =>
                                  _deleteCurrentCard(deck, currentCard),
                              onForget: _swipeLeft,
                              onRemember: _swipeRight,
                              onEdit: () => _openCardEditor(card: currentCard),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.reviewed,
    required this.total,
    required this.rememberedCount,
  });

  final int reviewed;
  final int total;
  final int rememberedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _HeaderChip(
          icon: Icons.local_fire_department_rounded,
          label: '$reviewed/$total',
          color: AppColors.deepPurple,
        ),
        const SizedBox(width: 10),
        _HeaderChip(
          icon: Icons.check_circle_rounded,
          label: '$rememberedCount nhớ',
          color: Colors.green,
        ),
        const Spacer(),
        const Icon(Icons.swipe_rounded, color: AppColors.periwinkle),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lavender),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FlashcardFrontFace extends StatelessWidget {
  const _FlashcardFrontFace({required this.card});

  final FlashcardCard card;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.lavender.withValues(alpha: 0.85),
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
                  card.english,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    color: AppColors.deepPurple,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pastelPink,
                    border: Border.all(
                      color: AppColors.periwinkle.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    size: 42,
                    color: AppColors.deepPurple,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Chạm để lật thẻ',
                  style: TextStyle(
                    color: AppColors.lightTextSecondary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Vuốt trái / phải để chấm điểm',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepPurple,
                      ),
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

class _FlashcardBackFace extends StatelessWidget {
  const _FlashcardBackFace({required this.card});

  final FlashcardCard card;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Mặt sau',
                    style: TextStyle(
                      color: AppColors.deepPurple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    final String? audioHint = card.example.isNotEmpty
                        ? card.example
                        : null;
                    if (audioHint == null) return;
                    await HapticFeedback.lightImpact();
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.pastelPink,
                    foregroundColor: AppColors.deepPurple,
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                  tooltip: 'Phát âm',
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              card.meaning,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.deepPurple,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Câu ví dụ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.lightTextSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: _HighlightedSentence(
                  sentence: card.example,
                  targetWord: card.english,
                ),
              ),
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
    if (sentence.trim().isEmpty) {
      return const Text(
        'Chưa có câu ví dụ.',
        style: TextStyle(
          color: AppColors.lightTextSecondary,
          height: 1.5,
          fontSize: 16,
        ),
      );
    }

    final RegExp pattern = RegExp(
      RegExp.escape(targetWord),
      caseSensitive: false,
    );

    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;

    for (final Match match in pattern.allMatches(sentence)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: sentence.substring(cursor, match.start)));
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              sentence.substring(match.start, match.end),
              style: const TextStyle(
                color: AppColors.deepPurple,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.lightText,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.lavender),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.deepPurple.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onDelete,
    required this.onForget,
    required this.onRemember,
    required this.onEdit,
  });

  final VoidCallback onDelete;
  final VoidCallback onForget;
  final VoidCallback onRemember;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _MiniActionButton(
          onTap: onDelete,
          icon: Icons.delete_rounded,
          backgroundColor: Colors.white,
          borderColor: Colors.redAccent,
          iconColor: Colors.redAccent,
        ),
        _DecisionButton(
          onTap: onForget,
          icon: Icons.close_rounded,
          borderColor: Colors.deepOrangeAccent,
          iconColor: Colors.deepOrangeAccent,
          label: 'Quên',
        ),
        _DecisionButton(
          onTap: onRemember,
          icon: Icons.check_rounded,
          borderColor: AppColors.deepPurple,
          iconColor: AppColors.deepPurple,
          label: 'Nhớ',
        ),
        _MiniActionButton(
          onTap: onEdit,
          icon: Icons.edit_rounded,
          backgroundColor: Colors.white,
          borderColor: AppColors.periwinkle,
          iconColor: AppColors.deepPurple,
        ),
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.onTap,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.onTap,
    required this.icon,
    required this.borderColor,
    required this.iconColor,
    required this.label,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color borderColor;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2.2),
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: borderColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EmptyStudyState extends StatelessWidget {
  const _EmptyStudyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.deepPurple.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: AppColors.deepPurple,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có flashcard nào trong bộ này',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.deepPurple,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bấm dấu cộng để thêm thẻ thủ công và bắt đầu ôn tập.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.lightTextSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm flashcard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardEditorSheet extends StatefulWidget {
  const _FlashcardEditorSheet({
    required this.title,
    required this.englishInitial,
    required this.meaningInitial,
  });

  final String title;
  final String englishInitial;
  final String meaningInitial;

  @override
  State<_FlashcardEditorSheet> createState() => _FlashcardEditorSheetState();
}

class _FlashcardEditorSheetState extends State<_FlashcardEditorSheet> {
  late final TextEditingController _englishController;
  late final TextEditingController _meaningController;

  @override
  void initState() {
    super.initState();
    _englishController = TextEditingController(text: widget.englishInitial);
    _meaningController = TextEditingController(text: widget.meaningInitial);
  }

  @override
  void dispose() {
    _englishController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  void _submit() {
    final String english = _englishController.text.trim();
    final String meaning = _meaningController.text.trim();

    if (english.isEmpty || meaning.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập cả tiếng Anh và nghĩa tiếng Việt.'),
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(FlashcardDraft(english: english, meaning: meaning));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.deepPurple.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepPurple,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _englishController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Tiếng Anh',
                        filled: true,
                        fillColor: AppColors.lavender.withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _meaningController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Nghĩa tiếng Việt',
                        filled: true,
                        fillColor: AppColors.lavender.withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Lưu flashcard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlashcardDraft {
  const FlashcardDraft({required this.english, required this.meaning});

  final String english;
  final String meaning;
}

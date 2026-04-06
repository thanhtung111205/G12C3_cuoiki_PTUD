import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/flashcard_provider.dart';
import '../../services/dictionary_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/flashcard_haptics.dart';
import '../../utils/shake_detector.dart';
import '../../widgets/flashcard_editor_sheet.dart';
import '../../widgets/flashcard_item_card.dart';
import '../../widgets/flashcard_study_components.dart';

class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({super.key, this.deckId});

  final String? deckId;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _shakeLockDuration = Duration(milliseconds: 4000);

  final FlashcardProvider _provider = FlashcardProvider.instance;
  final CardSwiperController _swiperController = CardSwiperController();
  int _swiperSession = 0;

  late String _deckId;
  int _frontIndex = 0;
  // Gamification: shake counter
  int _shakeCount = 0;
  DateTime _shakeLockUntil = DateTime.fromMillisecondsSinceEpoch(0);
  late final ShakeDetector _shakeDetector = ShakeDetector(
    isLocked: () => _isShakeLocked,
  );
  late final AnimationController _shakeAnimController;
  late final Animation<double> _shakeScale;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _deckId = widget.deckId ?? _provider.activeDeck.id;
    _provider.syncForUser(_userId);
    _provider.setActiveDeck(_deckId);
    // Start listening to shake events
    _shakeDetector.onShake.listen((_) => _onShakeDetected());
    _shakeDetector.onIgnoredShake.listen(
      (_) => FlashcardHaptics.cooldownThud(),
    );
    _shakeDetector.startListening();

    // Animation used to give visual feedback when shake occurs (brief scale pulse)
    _shakeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _shakeScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _shakeAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeDetector.dispose();
    _shakeAnimController.dispose();
    super.dispose();
  }

  bool get _isShakeLocked => DateTime.now().isBefore(_shakeLockUntil);

  void _onShakeDetected() {
    final FlashcardDeck deck = _deck;
    if (deck.cards.isEmpty) return;

    if (_isShakeLocked) {
      FlashcardHaptics.cooldownThud();
      return;
    }

    _shakeLockUntil = DateTime.now().add(_shakeLockDuration);

    // increase gamification counter
    setState(() {
      _shakeCount++;
      _frontIndex = 0; // reset to first card after shuffle
    });

    FlashcardHaptics.confirmShuffle();

    // run a short visual pulse animation
    _shakeAnimController
        .forward(from: 0)
        .then((_) => _shakeAnimController.reverse());

    // Capture previous order BEFORE shuffle so Undo can restore it
    final previousOrder = List<String>.from(deck.cards.map((c) => c.id));

    // Shuffle locally
    _provider.shuffleDeck(deck.id);

    // Hiển thị thông báo nhỏ gọn ở bên dưới
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepPurple.withOpacity(0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.12),
            width: 1,
          ), // Viền mờ nhẹ
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        content: Row(
          children: [
            const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Đã xáo trộn thẻ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              height: 24,
              width: 1,
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            TextButton(
              onPressed: () {
                final Map<String, FlashcardCard> map = {
                  for (var c in deck.cards) c.id: c,
                };
                final List<FlashcardCard> restored = previousOrder
                    .map((id) => map[id])
                    .whereType<FlashcardCard>()
                    .toList(growable: false);
                if (restored.isNotEmpty) {
                  _provider.setDeckOrder(deck.id, restored);
                }
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ), // Viền mờ nhẹ cho nút
                ),
              ),
              child: const Text(
                'Hoàn tác',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FlashcardDeck get _deck =>
      _provider.deckById(_deckId) ?? _provider.activeDeck;

  FlashcardCard? _currentCard(FlashcardDeck deck) {
    if (deck.cards.isEmpty) return null;
    final int safeIndex = _frontIndex.clamp(0, deck.cards.length - 1);
    return deck.cards[safeIndex];
  }

  bool _isDeckCompleted(FlashcardDeck deck) {
    return deck.cards.isNotEmpty && deck.reviewedCount >= deck.cards.length;
  }

  Future<void> _restartDeck(FlashcardDeck deck) async {
    final String? userId = _userId;
    if (userId == null) return;

    await _provider.restartDeck(userId, deck.id);
    if (!mounted) return;

    setState(() {
      _frontIndex = 0;
      _swiperSession += 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đưa bộ thẻ về trạng thái ban đầu.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmRestartDeck(FlashcardDeck deck) async {
    if (deck.cards.isEmpty) return;

    final bool shouldRestart =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Học lại từ đầu'),
              content: const Text(
                'Thao tác này sẽ đưa toàn bộ thẻ về trạng thái chưa học. Bạn có muốn tiếp tục không?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Restart'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRestart) return;
    await _restartDeck(deck);
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
        _userId!,
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
    final String? userId = _userId;
    if (userId == null) return;

    final FlashcardDeck deck = _deck;
    final FlashcardDraft? result = await showModalBottomSheet<FlashcardDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FlashcardEditorSheet(
          title: card == null ? 'Thêm flashcard' : 'Chỉnh sửa flashcard',
          englishInitial: card?.english ?? '',
          meaningInitial: card?.meaning ?? '',
        );
      },
    );

    if (result == null) return;

    if (card == null) {
      String? audioUrl;
      String? phonetic;
      try {
        final entry = await DictionaryService().lookupWord(result.english);
        if (entry.audioUrl.isNotEmpty) audioUrl = entry.audioUrl;
        if (entry.phonetic.isNotEmpty) phonetic = entry.phonetic;
      } catch (_) {}

      await _provider.addCard(
        userId,
        deck.id,
        english: result.english,
        meaning: result.meaning,
        audioUrl: audioUrl,
        phonetic: phonetic,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm flashcard.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _provider.updateCard(
      userId,
      deck.id,
      card.id,
      english: result.english,
      meaning: result.meaning,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật flashcard.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _swipeLeft() {
    _swiperController.swipe(CardSwiperDirection.left);
  }

  void _swipeRight() {
    _swiperController.swipe(CardSwiperDirection.right);
  }

  void _deleteCurrentCard(FlashcardDeck deck, FlashcardCard card) {
    final String? userId = _userId;
    if (userId == null) return;

    final int removedIndex = _frontIndex;
    final FlashcardCard removedCard = card;
    _provider.deleteCard(userId, deck.id, removedCard.id);

    if (mounted) {
      setState(() {
        _frontIndex = 0;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: <Widget>[
                const Expanded(child: Text('Đã xoá flashcard')),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.periwinkle,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    _provider.restoreCard(userId, deck.id, removedCard);
                    if (mounted) {
                      setState(() {
                        _frontIndex = removedIndex;
                      });
                    }
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  child: const Text('Hoàn tác'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _provider,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final Color pageBackground = isDark
            ? AppColors.darkBackground
            : AppColors.pastelPink;
        final Color pageSurface = isDark ? AppColors.darkSurface : Colors.white;
        final Color pageForeground = isDark
            ? AppColors.darkText
            : AppColors.deepPurple;
        final Color pageSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        final FlashcardDeck deck =
            _provider.deckById(_deckId) ?? _provider.activeDeck;
        final FlashcardCard? currentCard = _currentCard(deck);
        final int totalCards = deck.cards.length;
        final bool compactHeight = MediaQuery.sizeOf(context).height < 720;
        final int reviewedCards = deck.reviewedCount;
        final double progress = deck.progress;
        final bool isCompleted = _isDeckCompleted(deck);
        final int rememberedCards = deck.cards
            .where((FlashcardCard card) => card.rememberedLastTime == true)
            .length;
        final int forgottenCards = deck.cards
            .where((FlashcardCard card) => card.rememberedLastTime == false)
            .length;

        return GestureDetector(
          onTap: () {
            // Đóng SnackBar khi chạm ra ngoài
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardAreaHeight = compactHeight
                  ? constraints.maxHeight * 0.54
                  : constraints.maxHeight * 0.62;

              return Scaffold(
                backgroundColor: pageBackground,
                appBar: AppBar(
                  backgroundColor: pageBackground,
                  foregroundColor: pageForeground,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    deck.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  iconTheme: IconThemeData(color: pageForeground),
                  actions: <Widget>[
                    // Khôi phục nút Restart (Reset)
                    IconButton(
                      onPressed: () => _confirmRestartDeck(deck),
                      icon: const Icon(Icons.restart_alt_rounded),
                      tooltip: 'Học lại từ đầu',
                    ),
                    IconButton(
                      onPressed: _onShakeDetected,
                      icon: const Icon(Icons.shuffle_rounded),
                      tooltip: 'Xáo trộn',
                    ),
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
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.65),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Đã ôn $reviewedCards/$totalCards',
                                style: TextStyle(
                                  color: pageSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                totalCards == 0
                                    ? '0%'
                                    : '${(progress * 100).round()}%',
                                style: TextStyle(
                                  color: pageForeground,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[pageBackground, pageSurface],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: totalCards == 0
                        ? EmptyStudyState(onAdd: () => _openCardEditor())
                        : isCompleted
                        ? CompletedStudyState(
                            reviewed: reviewedCards,
                            total: totalCards,
                            remembered: rememberedCards,
                            forgotten: forgottenCards,
                            onRestart: () => _confirmRestartDeck(deck),
                            onAdd: () => _openCardEditor(),
                          )
                        : SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  18,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    StudyHeader(
                                      reviewed: reviewedCards,
                                      total: totalCards,
                                      rememberedCount: deck.cards
                                          .where(
                                            (FlashcardCard card) =>
                                                card.rememberedLastTime == true,
                                          )
                                          .length,
                                    ),
                                    SizedBox(height: compactHeight ? 10 : 16),
                                    SizedBox(
                                      height: cardAreaHeight,
                                      child: Center(
                                        child: AspectRatio(
                                          aspectRatio: compactHeight
                                              ? 0.66
                                              : 0.78,
                                          child: ScaleTransition(
                                            scale: _shakeScale,
                                            child: CardSwiper(
                                              key: ValueKey(_swiperSession),
                                              controller: _swiperController,
                                              cardsCount: deck.cards.length,
                                              numberOfCardsDisplayed:
                                                  deck.cards.length < 2
                                                  ? deck.cards.length
                                                  : 2,
                                              isLoop: false,
                                              duration: const Duration(
                                                milliseconds: 340,
                                              ),
                                              threshold: 55,
                                              scale: 0.95,
                                              padding: EdgeInsets.zero,
                                              onSwipe: _onSwipe,
                                              onEnd: () {
                                                HapticFeedback.mediumImpact();
                                              },
                                              cardBuilder:
                                                  (
                                                    BuildContext context,
                                                    int index,
                                                    int
                                                    horizontalOffsetPercentage,
                                                    int
                                                    verticalOffsetPercentage,
                                                  ) {
                                                    final FlashcardCard card =
                                                        deck.cards[index];
                                                    return FlashcardItemCard(
                                                      card: card,
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: compactHeight ? 10 : 18),
                                    if (currentCard != null)
                                      ActionRow(
                                        compactHeight: compactHeight,
                                        onDelete: () => _deleteCurrentCard(
                                          deck,
                                          currentCard,
                                        ),
                                        onForget: _swipeLeft,
                                        onRemember: _swipeRight,
                                        onEdit: () =>
                                            _openCardEditor(card: currentCard),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

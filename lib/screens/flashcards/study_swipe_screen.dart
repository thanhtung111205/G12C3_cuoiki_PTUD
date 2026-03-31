import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/flashcard_provider.dart';
import '../../services/dictionary_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/shake_detector.dart';
import '../../widgets/flashcard_item_card.dart';

class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({super.key, this.deckId});

  final String? deckId;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> with SingleTickerProviderStateMixin {
   final FlashcardProvider _provider = FlashcardProvider.instance;
   final CardSwiperController _swiperController = CardSwiperController();

   late String _deckId;
   int _frontIndex = 0;
   // Gamification: shake counter
   int _shakeCount = 0;
   late final ShakeDetector _shakeDetector = ShakeDetector();
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

  void _onShakeDetected() {
     final FlashcardDeck deck = _deck;
     if (deck.cards.isEmpty) return;

     // increase gamification counter
     setState(() {
       _shakeCount++;
       _frontIndex = 0; // reset to first card after shuffle
     });

     // provide haptic feedback
     // Use a stronger impact for clearer feedback on supported devices
    try {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 40), () => HapticFeedback.mediumImpact());
    } catch (_) {}


    // run a short visual pulse animation
    _shakeAnimController.forward(from: 0).then((_) => _shakeAnimController.reverse());

    // Capture previous order BEFORE shuffle so Undo can restore it
    final previousOrder = List<String>.from(deck.cards.map((c) => c.id));

    // Shuffle locally
    _provider.shuffleDeck(deck.id);


    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(MaterialBanner(
        content: Text('Đã xáo trộn thứ tự thẻ — Lần lắc: $_shakeCount'),
        leading: const Icon(Icons.shuffle_rounded),
        actions: [
          TextButton(
            onPressed: () {
              // Attempt to restore previous order (best-effort: reorder by previous ids)
              final Map<String, FlashcardCard> map = { for (var c in deck.cards) c.id: c };
              final List<FlashcardCard> restored = previousOrder
                  .map((id) => map[id])
                  .whereType<FlashcardCard>()
                  .toList(growable: false);
              if (restored.isNotEmpty) {
                // Use provider method to set order and notify listeners
                _provider.setDeckOrder(deck.id, restored);
              }
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Hoàn tác'),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Đóng'),
          ),
        ],
      ));
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
      _swiperController = CardSwiperController();
      _swiperSession += 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đưa bộ thẻ về trạng thái ban đầu.')),
    );
  }

  Future<void> _confirmRestartDeck(FlashcardDeck deck) async {
    if (deck.cards.isEmpty) return;

    final bool shouldRestart = await showDialog<bool>(
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
        return _FlashcardEditorSheet(
          title: card == null ? 'Thêm flashcard' : 'Chỉnh sửa flashcard',
          englishInitial: card?.english ?? '',
          meaningInitial: card?.meaning ?? '',
        );
      },
    );

    if (result == null) return;

    if (card == null) {
      // ── Fetch audio from dictionary (best-effort; never blocks save) ──────
      String? audioUrl;
      String? phonetic;
      try {
        final entry = await DictionaryService().lookupWord(result.english);
        if (entry.audioUrl.isNotEmpty) audioUrl = entry.audioUrl;
        if (entry.phonetic.isNotEmpty) phonetic = entry.phonetic;
      } catch (_) {
        // 404 or network error → silently ignore, save card without audio
      }

      await _provider.addCard(
        userId,
        deck.id,
        english: result.english,
        meaning: result.meaning,
        audioUrl: audioUrl,
        phonetic: phonetic,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    audioUrl != null
                        ? 'Đã thêm "${result.english}" kèm phát âm ✨'
                        : 'Đã thêm "${result.english}" (không có audio)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.deepPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await _provider.updateCard(
      userId,
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
    final String? userId = _userId;
    if (userId == null) return;

    final int removedIndex = _frontIndex;
    final FlashcardCard removedCard = card;
    _provider.deleteCard(userId, deck.id, removedCard.id);

    if (mounted) {
      setState(() {
        _frontIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xoá flashcard'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: AppColors.periwinkle,
            onPressed: () {
              _provider.restoreCard(userId, deck.id, removedCard);
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
        final bool isCompleted = _isDeckCompleted(deck);
        final int rememberedCards = deck.cards
          .where((FlashcardCard card) => card.rememberedLastTime == true)
          .length;
        final int forgottenCards = deck.cards
          .where((FlashcardCard card) => card.rememberedLastTime == false)
          .length;

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
              // Debug shuffle button (useful to test haptic & animation without physically shaking)
              IconButton(
                onPressed: _onShakeDetected,
                icon: const Icon(Icons.shuffle_rounded),
                tooltip: 'Xáo trộn (thử)',
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
                    : isCompleted
                        ? _CompletedStudyState(
                            reviewed: reviewedCards,
                            total: totalCards,
                            remembered: rememberedCards,
                            forgotten: forgottenCards,
                            onRestart: () => _restartDeck(deck),
                            onAdd: () => _openCardEditor(),
                          )
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
                                child: ScaleTransition(
                                  scale: _shakeScale,
                                  child: CardSwiper(
                                   controller: _swiperController,
                                   cardsCount: deck.cards.length,
                                   numberOfCardsDisplayed: deck.cards.length < 2
                                       ? deck.cards.length
                                       : 2,
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
                                         return FlashcardItemCard(card: card);
                                       },
                                  ),
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

class _CompletedStudyState extends StatelessWidget {
  const _CompletedStudyState({
    required this.reviewed,
    required this.total,
    required this.remembered,
    required this.forgotten,
    required this.onRestart,
    required this.onAdd,
  });

  final int reviewed;
  final int total;
  final int remembered;
  final int forgotten;
  final VoidCallback onRestart;
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
              width: 96,
              height: 96,
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
                Icons.verified_rounded,
                color: AppColors.deepPurple,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Bạn đã học hết bộ flashcard này',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.deepPurple,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã hoàn thành $reviewed/$total thẻ. Bấm restart để học lại từ đầu.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.lightTextSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                _SummaryChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Nhớ $remembered',
                  color: Colors.green,
                ),
                _SummaryChip(
                  icon: Icons.close_rounded,
                  label: 'Quên $forgotten',
                  color: Colors.deepOrangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRestart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restart bộ thẻ'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm flashcard mới'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  bool _isSaving = false;

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

  Future<void> _submit() async {
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

    setState(() => _isSaving = true);

    // Small delay to let the loading indicator render before
    // the caller's async work (audio fetch + Firestore) begins.
    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (mounted) {
      Navigator.of(
        context,
      ).pop(FlashcardDraft(english: english, meaning: meaning));
    }
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
                      enabled: !_isSaving,
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
                      enabled: !_isSaving,
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
              const SizedBox(height: 12),
              // Hint about audio fetch
              if (widget.englishInitial.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.periwinkle,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Audio phát âm sẽ được tự động tìm kiếm từ từ điển.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.periwinkle,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lưu flashcard'),
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

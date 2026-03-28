import 'package:flutter/material.dart';

import '../../providers/flashcard_provider.dart';
import '../../utils/app_colors.dart';
import 'study_swipe_screen.dart';

class FlashcardDeckScreen extends StatelessWidget {
  const FlashcardDeckScreen({super.key});

  FlashcardProvider get _provider => FlashcardProvider.instance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.pastelPink,
      appBar: AppBar(
        backgroundColor: AppColors.pastelPink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Bộ từ vựng của tôi',
          style: TextStyle(
            color: AppColors.deepPurple,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.deepPurple),
      ),
      body: AnimatedBuilder(
        animation: _provider,
        builder: (BuildContext context, Widget? child) {
          final List<FlashcardDeck> decks = _provider.decks;

          if (decks.isEmpty) {
            return _EmptyDeckState(theme: theme);
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: decks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (BuildContext context, int index) {
              final FlashcardDeck deck = decks[index];
              return _DeckCard(
                deck: deck,
                onTap: () {
                  _provider.setActiveDeck(deck.id);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FlashcardStudyScreen(deckId: deck.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.onTap});

  final FlashcardDeck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int reviewed = deck.reviewedCount;
    final int total = deck.cards.length;
    final double progress = deck.progress;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.lavender),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.deepPurple.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.deepPurple, AppColors.periwinkle],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      deck.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      total == 1 ? '1 thẻ' : '$total thẻ',
                      style: const TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.lavender,
                        color: AppColors.periwinkle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      total == 0 ? 'Chưa có thẻ' : 'Đã ôn $reviewed/$total thẻ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.periwinkle,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeckState extends StatelessWidget {
  const _EmptyDeckState({required this.theme});

  final ThemeData theme;

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
                borderRadius: BorderRadius.circular(28),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.deepPurple.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.deepPurple,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có bộ từ vựng nào',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.deepPurple,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thêm dữ liệu mẫu hoặc tạo bộ mới để bắt đầu học.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.lightTextSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

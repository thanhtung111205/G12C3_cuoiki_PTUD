import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../providers/flashcard_provider.dart';
import '../../utils/app_colors.dart';
import 'study_swipe_screen.dart';

class FlashcardDeckScreen extends StatefulWidget {
  const FlashcardDeckScreen({super.key});

  @override
  State<FlashcardDeckScreen> createState() => _FlashcardDeckScreenState();
}

class _FlashcardDeckScreenState extends State<FlashcardDeckScreen> {
  final FlashcardProvider _provider = FlashcardProvider.instance;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _provider.syncForUser(_userId);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color pageBackground =
        isDark ? AppColors.darkBackground : AppColors.pastelPink;
    final Color pageForeground = isDark ? AppColors.darkText : AppColors.deepPurple;
    final String? userId = _userId;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: pageForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Bộ từ vựng của tôi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        iconTheme: IconThemeData(color: pageForeground),
        actions: <Widget>[
          IconButton(
            onPressed: userId == null
                ? null
                : () => _showDeckEditor(context, userId: userId),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Thêm bộ thẻ',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _provider,
        builder: (BuildContext context, Widget? child) {
          final List<FlashcardDeck> decks = _provider.decks;

          if (userId == null) {
            return const Center(
              child: Text('Không xác định được người dùng hiện tại.'),
            );
          }

          if (decks.isEmpty) {
            return _EmptyDeckState(
              theme: theme,
              onAdd: () => _showDeckEditor(context, userId: userId),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: decks.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 14),
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
                onEdit: () =>
                    _showDeckEditor(context, userId: userId, deck: deck),
                onDelete: () => _confirmDeleteDeck(context, userId, deck),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showDeckEditor(
    BuildContext context, {
    required String userId,
    FlashcardDeck? deck,
  }) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _DeckEditorDialog(
          initialTitle: deck?.title ?? '',
          isNew: deck == null,
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;

    if (deck == null) {
      await _provider.addDeck(userId, title: result);
    } else {
      await _provider.updateDeck(userId, deck.id, result);
    }
  }

  Future<void> _confirmDeleteDeck(
    BuildContext context,
    String userId,
    FlashcardDeck deck,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xoá bộ thẻ?'),
          content: Text(
            'Xoá "${deck.title}" sẽ xoá toàn bộ flashcard bên trong.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xoá'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _provider.deleteDeck(userId, deck.id);
    }
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.deck,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final FlashcardDeck deck;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? AppColors.darkCard : Colors.white;
    final Color border = isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lavender;
    final Color titleColor = isDark ? AppColors.darkText : AppColors.deepPurple;
    final Color secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color shadow = isDark
        ? Colors.black.withValues(alpha: 0.32)
        : AppColors.deepPurple.withValues(alpha: 0.06);

    final int reviewed = deck.reviewedCount;
    final int total = deck.cards.length;
    final double progress = deck.progress;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shadow,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(total == 1 ? '1 thẻ' : '$total thẻ', style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lavender,
                        color: AppColors.periwinkle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      total == 0 ? 'Chưa có thẻ' : 'Đã ôn $reviewed/$total thẻ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Chỉnh sửa'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Xoá'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeckState extends StatelessWidget {
  const _EmptyDeckState({required this.theme, this.onAdd});

  final ThemeData theme;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? AppColors.darkCard : Colors.white;
    final Color primaryText = isDark ? AppColors.darkText : AppColors.deepPurple;
    final Color secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                color: surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
                color: primaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thêm dữ liệu mẫu hoặc tạo bộ mới để bắt đầu học.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, height: 1.45),
            ),
            if (onAdd != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm bộ thẻ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckEditorDialog extends StatefulWidget {
  const _DeckEditorDialog({required this.initialTitle, required this.isNew});

  final String initialTitle;
  final bool isNew;

  @override
  State<_DeckEditorDialog> createState() => _DeckEditorDialogState();
}

class _DeckEditorDialogState extends State<_DeckEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Thêm bộ thẻ' : 'Chỉnh sửa bộ thẻ'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Tên bộ thẻ'),
        onSubmitted: (String value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}


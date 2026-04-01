import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/flashcard_provider.dart';
import '../../../utils/app_colors.dart';
import 'create_deck_dialog.dart';

class SmartSaveBottomSheet extends StatefulWidget {
  const SmartSaveBottomSheet({
    super.key,
    required this.word,
    required this.meaning,
    this.pronunciation = '',
    this.audioUrl = '',
    required this.onSave,
  });

  final String word;
  final String meaning;
  final String pronunciation;
  final String audioUrl;
  final Function(String deckId, String deckName) onSave;

  @override
  State<SmartSaveBottomSheet> createState() => _SmartSaveBottomSheetState();
}

class _SmartSaveBottomSheetState extends State<SmartSaveBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateDeck() async {
    // The context is captured here before any async gap.
    final currentContext = context;

    final String? deckNameToCreate = await showDialog<String>(
      context: currentContext,
      builder: (_) => const CreateDeckDialog(),
    );

    // 3. Check for cancellation or unmounted widget *after* the dialog is gone.
    if (deckNameToCreate == null || deckNameToCreate.isEmpty || !mounted) {
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create new deck
      final deckId = await FlashcardProvider.instance.addDeck(
        userId,
        title: deckNameToCreate,
      );

      if (!mounted) return;

      // Add word to new deck
      await FlashcardProvider.instance.addCard(
        userId,
        deckId,
        english: widget.word,
        meaning: widget.meaning,
        phonetic: widget.pronunciation,
        audioUrl: widget.audioUrl,
      );

      if (!mounted) return;

      // Show success notification and pop using the captured context
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('Đã lưu "${widget.word}" vào $deckNameToCreate'),
          backgroundColor: AppColors.deepPurple,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(currentContext);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSaveToDeck(String deckId, String deckName) {
    widget.onSave(deckId, deckName);
    // Show success toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu "${widget.word}" vào $deckName'),
        backgroundColor: AppColors.deepPurple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
    Navigator.pop(context);
  }

  List<FlashcardDeck> _getFilteredDecks(List<FlashcardDeck> decks) {
    if (_searchQuery.isEmpty) {
      return decks;
    }
    return decks
        .where((deck) =>
            deck.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final flashcardProvider = FlashcardProvider.instance;
    final allDecks = flashcardProvider.decks;
    final filteredDecks = _getFilteredDecks(allDecks);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lưu từ vựng',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${widget.word}"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF231A3D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm bộ Flashcard...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Decks List
              Expanded(
                child: filteredDecks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Chưa có bộ Flashcard nào'
                                  : 'Không tìm thấy bộ Flashcard',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredDecks.length,
                        itemBuilder: (context, index) {
                          final deck = filteredDecks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _handleSaveToDeck(
                                    deck.id,
                                    deck.title,
                                  );
                                },
                                borderRadius:
                                    BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.lavender
                                        .withOpacity(0.1),
                                    border: Border.all(
                                      color: AppColors.lavender
                                          .withOpacity(0.3),
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.lavender
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  8),
                                        ),
                                        child: const Icon(
                                          Icons.folder_open,
                                          size: 20,
                                          color:
                                              AppColors.deepPurple,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              deck.title,
                                              style:
                                                  const TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: Color(
                                                    0xFF231A3D),
                                              ),
                                            ),
                                            const SizedBox(
                                                height: 2),
                                            Text(
                                              '${deck.cardCount} từ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Colors.grey[
                                                        600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons
                                            .arrow_forward_ios,
                                        size: 14,
                                        color:
                                            AppColors.periwinkle,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Create new deck button - Always visible
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  top: 12,
                ),
                child: OutlinedButton.icon(
                  onPressed: _handleCreateDeck,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ Tạo Bộ Flashcard'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.periwinkle,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

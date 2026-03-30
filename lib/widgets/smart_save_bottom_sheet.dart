// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../providers/flashcard_provider.dart';
import '../services/dictionary_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC ENTRY-POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the [SmartSaveBottomSheet] as a modal bottom sheet.
///
/// [word]   – the highlighted word to look up & save
/// [userId] – optional override; defaults to the current Firebase user
Future<void> showSmartSaveBottomSheet(
  BuildContext context, {
  required String word,
  String? userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SmartSaveBottomSheet(word: word, userId: userId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Premium bottom sheet for saving a highlighted word to a flashcard deck.
///
/// Flow: user picks a deck  ──▶  [FirestoreService.saveWordToDeck]
///         ├─ calls [DictionaryService.lookupWord]
///         ├─ maps result → Firestore card doc
///         └─ atomically increments deck.cardCount
class SmartSaveBottomSheet extends StatefulWidget {
  const SmartSaveBottomSheet({
    super.key,
    required this.word,
    this.userId,
  });

  final String word;
  final String? userId;

  @override
  State<SmartSaveBottomSheet> createState() => _SmartSaveBottomSheetState();
}

class _SmartSaveBottomSheetState extends State<SmartSaveBottomSheet> {
  // ── Services ──────────────────────────────────────────────────────────────
  final FirestoreService _firestoreService = FirestoreService();

  // ── Local state ───────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _savingDeckId;   // deckId currently being saved (shows per-item loader)
  bool _isSaving = false;  // global flag to prevent double-tap

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<FlashcardDeck> _filtered(List<FlashcardDeck> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((d) => d.title.toLowerCase().contains(q)).toList();
  }

  void _onSearchChanged(String value) =>
      setState(() => _query = value.trim());

  // ── Save logic ────────────────────────────────────────────────────────────

  Future<void> _saveWord(String deckId) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _savingDeckId = deckId;
    });

    try {
      await _firestoreService.saveWordToDeck(
        word: widget.word,
        deckId: deckId,
        userId: widget.userId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close sheet first

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Đã lưu "${widget.word}" vào bộ thẻ thành công ✨',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
    } on WordNotFoundException {
      if (!mounted) return;
      _showErrorSnack(
          'Không tìm thấy nghĩa của "${widget.word}" trong từ điển.');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('Lỗi: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingDeckId = null;
        });
      }
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Create new deck dialog ────────────────────────────────────────────────

  void _showCreateDeckDialog(FlashcardProvider provider) {
    final TextEditingController nameCtrl = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool creating = false;

    showDialog<void>(
      context: context,
      barrierDismissible: !creating,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Tạo bộ Flashcard mới',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Tên bộ thẻ...',
                    prefixIcon: const Icon(Icons.folder_rounded,
                        color: AppColors.periwinkle),
                    filled: true,
                    fillColor:
                        Theme.of(ctx).brightness == Brightness.dark
                            ? AppColors.darkCard
                            : AppColors.lavender,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tên bộ thẻ'
                          : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      creating ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => creating = true);

                          final uid = provider.currentUserId ?? '';
                          if (uid.isEmpty) {
                            setDialogState(() => creating = false);
                            return;
                          }

                          try {
                            await provider.addDeck(uid,
                                title: nameCtrl.text.trim());
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                          } catch (_) {
                            setDialogState(() => creating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Tạo',
                          style:
                              TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double sheetHeight =
        MediaQuery.of(context).size.height * 0.48;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Title row
                Text(
                  'Lưu từ vựng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                // Highlighted word chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.deepPurple.withValues(alpha: 0.3)
                        : AppColors.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '"${widget.word}"',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.periwinkle
                          : AppColors.deepPurple,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Search bar ──────────────────────────────────────────
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm bộ thẻ...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkCard
                        : const Color(0xFFF4F2FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Deck list (scrollable) ──────────────────────────────────────
          Expanded(
            child: ListenableBuilder(
              listenable: FlashcardProvider.instance,
              builder: (ctx, _) {
                final provider = FlashcardProvider.instance;
                final decks = _filtered(provider.decks);

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: decks.length + 1, // +1 for "Create" button
                  itemBuilder: (_, index) {
                    // ── Create deck button (first item) ──────────────────
                    if (index == 0) {
                      return _CreateDeckButton(
                        isDark: isDark,
                        onTap: () => _showCreateDeckDialog(provider),
                      );
                    }

                    final deck = decks[index - 1];
                    final isSaving = _savingDeckId == deck.id;

                    return _DeckTile(
                      deck: deck,
                      isDark: isDark,
                      isSaving: isSaving,
                      isDisabled: _isSaving,
                      onTap: () => _saveWord(deck.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CreateDeckButton extends StatelessWidget {
  const _CreateDeckButton({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark
                    ? AppColors.periwinkle.withValues(alpha: 0.35)
                    : AppColors.deepPurple.withValues(alpha: 0.25),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? AppColors.deepPurple.withValues(alpha: 0.08)
                  : AppColors.lavender.withValues(alpha: 0.6),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.deepPurple.withValues(alpha: 0.3)
                        : AppColors.lavender,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.deepPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '+ Tạo Bộ Flashcard',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepPurple
                        .withValues(alpha: isDark ? 0.85 : 1.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.isDark,
    required this.isSaving,
    required this.isDisabled,
    required this.onTap,
  });

  final FlashcardDeck deck;
  final bool isDark;
  final bool isSaving;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDisabled ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? (isSaving
                      ? AppColors.deepPurple.withValues(alpha: 0.2)
                      : AppColors.darkCard)
                  : (isSaving
                      ? AppColors.lavender.withValues(alpha: 0.8)
                      : const Color(0xFFF9F8FD)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSaving
                    ? AppColors.deepPurple.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // ── Folder icon ──────────────────────────────────────────
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.deepPurple.withValues(alpha: 0.25)
                        : AppColors.lavender,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: AppColors.periwinkle,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // ── Deck name ────────────────────────────────────────────
                Expanded(
                  child: Text(
                    deck.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // ── Card count / loader ──────────────────────────────────
                if (isSaving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.deepPurple,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : const Color(0xFFEEEAF8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${deck.cardCount} thẻ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
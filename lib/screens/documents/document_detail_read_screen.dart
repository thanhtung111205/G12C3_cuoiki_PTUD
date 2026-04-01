import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/dictionary_entry_model.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/flashcard_provider.dart';
import '../../services/dictionary_service.dart';
import '../../services/translation_service.dart';
import '../../translation/debounce.dart';
import '../../utils/app_colors.dart';
import 'document_editor_screen.dart';
import 'widgets/dictionary_popup.dart';
import 'widgets/smart_save_bottom_sheet.dart';

class DocumentDetailReadScreen extends StatefulWidget {
  const DocumentDetailReadScreen({super.key, required this.document});

  final DocumentModel document;

  @override
  State<DocumentDetailReadScreen> createState() =>
      _DocumentDetailReadScreenState();
}

class _DocumentDetailReadScreenState extends State<DocumentDetailReadScreen> {
  late DocumentProvider _documentProvider;
  final DictionaryService _dictionaryService = DictionaryService();
  final TranslationService _translationService = TranslationService();
  late Debouncer<String> _selectionDebouncer;

  String? _selectedWord;
  String? _selectedMeaning;
  String? _selectedPronunciation;
  String? _selectedAudioUrl;
  bool _showDictionaryPopup = false;
  bool _isBottomSheetOpen = false;
  TextSelection _lastSelection = const TextSelection(baseOffset: 0, extentOffset: 0);

  @override
  void initState() {
    super.initState();
    _documentProvider = DocumentProvider.instance;
    
    // Setup debouncer for text selection (400ms delay)
    _selectionDebouncer = Debouncer<String>(
      delay: const Duration(milliseconds: 400),
    );
    _selectionDebouncer.action = (selectedText) {
      if (selectedText.trim().isEmpty || selectedText.length > 100) return;
      if (_isBottomSheetOpen) return;
      _handleTextSelection(selectedText.trim());
    };
  }

  @override
  void dispose() {
    _selectionDebouncer.dispose();
    super.dispose();
  }

  Future<void> _handleTextSelection(String selectedText) async {
    if (selectedText.trim().isEmpty) return;

    final word = selectedText.trim();
    print('Looking up: $word');

    try {
      // Step 1: Translate the word directly to Vietnamese (concise, like Google Translate)
      final vietnameseMeaning = await _translationService.translate(
        word,
        from: 'en',
        to: 'vi',
      );

      // Step 2: Get pronunciation and audio from dictionary
      final dictionaryResult = await _dictionaryService.lookupWord(word);

      // Use Vietnamese translation if available
      final finalMeaning = vietnameseMeaning.isNotEmpty 
          ? vietnameseMeaning 
          : word;

      if (mounted && finalMeaning.isNotEmpty) {
        print('Found: $word - Meaning: $finalMeaning');
        setState(() {
          _selectedWord = word;
          _selectedMeaning = finalMeaning;
          _selectedPronunciation = dictionaryResult?.phonetic ?? '';
          _selectedAudioUrl = dictionaryResult?.audioUrl ?? '';
          _showDictionaryPopup = true;
        });

        // Auto-hide popup after 8 seconds if not interacting
        Future.delayed(const Duration(seconds: 8)).then((_) {
          if (mounted && _showDictionaryPopup) {
            setState(() => _showDictionaryPopup = false);
          }
        });
      }
    } catch (e) {
      print('Lookup error: $e');
    }
  }

  void _showSmartSaveBottomSheet() {
    if (_selectedWord == null || _selectedMeaning == null) return;

    setState(() => _isBottomSheetOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => SmartSaveBottomSheet(
        word: _selectedWord!,
        meaning: _selectedMeaning!,
        pronunciation: _selectedPronunciation ?? '',
        audioUrl: _selectedAudioUrl ?? '',
        onSave: (deckId, deckName) async {
          try {
            // Get FlashcardProvider to save the word
            final flashcardProvider = FlashcardProvider.instance;

            // Add card to flashcard deck
            await flashcardProvider.addCard(
              flashcardProvider.currentUserId!,
              deckId,
              english: _selectedWord!,
              meaning: _selectedMeaning!,
              phonetic: _selectedPronunciation,
              audioUrl: _selectedAudioUrl,
            );

            if (mounted) {
              // Hide bottom sheet
              Navigator.pop(bottomSheetContext);
              setState(() => _isBottomSheetOpen = false);
              // Hide dictionary popup
              setState(() => _showDictionaryPopup = false);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lỗi khi lưu từ: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isBottomSheetOpen = false);
      }
    });
  }

  void _onEdit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentEditorScreen(document: widget.document),
      ),
    );
  }

  void _onDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tài liệu'),
        content: const Text('Bạn có chắc chắn muốn xóa tài liệu này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _documentProvider.deleteDocument(widget.document.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tài liệu đã được xóa thành công'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đọc Tài Liệu'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _onEdit,
            tooltip: 'Chỉnh sửa',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _onDelete,
            tooltip: 'Xóa',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.document.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF231A3D),
                  ),
                ),
                const SizedBox(height: 12),

                // Document Info
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.document.wordCount} từ • Cập nhật: ${_formatDate(widget.document.updatedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tags
                if (widget.document.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.document.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Divider
                Divider(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                const SizedBox(height: 20),

                // Content - Selectable for dictionary
                SelectableText(
                  widget.document.content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF231A3D),
                    height: 1.8,
                    letterSpacing: 0.3,
                  ),
                  onSelectionChanged: (TextSelection selection, dynamic state) {
                    if (!selection.isCollapsed) {
                      final start = selection.start.clamp(0, widget.document.content.length);
                      final end = selection.end.clamp(0, widget.document.content.length);
                      
                      if (start < end) {
                        final selectedText = widget.document.content
                            .substring(start, end)
                            .trim();
                        
                        if (selectedText.isNotEmpty && selectedText.length <= 100) {
                          // Use debouncer to avoid rapid calls
                          _selectionDebouncer.call(selectedText);
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Dictionary Popup Overlay
          if (_showDictionaryPopup &&
              _selectedWord != null &&
              _selectedMeaning != null) ...[
            // Tap-to-dismiss background
            GestureDetector(
              onTap: () {
                setState(() => _showDictionaryPopup = false);
              },
              child: Container(
                color: Colors.black.withOpacity(0.0),
              ),
            ),
            // Dictionary Popup
            DictionaryPopup(
              word: _selectedWord!,
              pronunciation: _selectedPronunciation ?? '',
              meaning: _selectedMeaning!,
              audioUrl: _selectedAudioUrl ?? '',
              onSave: _showSmartSaveBottomSheet,
              offset: Offset.zero,
            ),
          ],
        ],
      ),
    );
  }
}

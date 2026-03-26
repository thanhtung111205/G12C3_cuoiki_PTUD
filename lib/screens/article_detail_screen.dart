import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/article.dart';
import '../models/dictionary_entry.dart';
import '../services/dictionary_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Track currently processing word to avoid duplicate lookups
  String _currentLookupWord = "";

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    if (selection.start >= 0 && selection.end > selection.start) {
      final text = widget.article.content.isNotEmpty ? widget.article.content : widget.article.description;
      
      String selectedText = text.substring(selection.start, selection.end);
      
      // Clean up the string to remove punctuation and whitespace
      String word = selectedText.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      
      // Only lookup if it's a single word with no spaces and not empty
      if (word.isNotEmpty && !word.contains(' ') && word != _currentLookupWord) {
        _currentLookupWord = word;
        _lookupWord(word);
      }
    }
  }

  Future<void> _lookupWord(String word) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: FutureBuilder<DictionaryEntry>(
            future: _dictionaryService.lookupWord(word),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    heightFactor: 1.0,
                    child: CircularProgressIndicator()
                  ),
                );
              } else if (snapshot.hasError) {
                // Hide bottom sheet and show SnackBar on error
                WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                   }
                   if (snapshot.error is WordNotFoundException || snapshot.error.toString().contains('WordNotFoundException')) {
                      ScaffoldMessenger.of(widget.key != null ? context : this.context).showSnackBar(
                        const SnackBar(content: Text('Không tìm thấy nghĩa của từ'))
                      );
                   } else {
                      ScaffoldMessenger.of(widget.key != null ? context : this.context).showSnackBar(
                        SnackBar(content: Text('Lỗi: ${snapshot.error}'))
                      );
                   }
                   _currentLookupWord = ""; // Reset
                });
                return const SizedBox.shrink();
              } else if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
          
              final entry = snapshot.data!;
              return _buildDictionaryResult(entry);
            },
          ),
        );
      }
    ).whenComplete(() {
        _currentLookupWord = "";
    });
  }

  Widget _buildDictionaryResult(DictionaryEntry entry) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.word,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                if (entry.audioUrl.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.blue, size: 28),
                    onPressed: () async {
                      try {
                        await _audioPlayer.play(UrlSource(entry.audioUrl));
                      } catch (e) {
                        debugPrint('Error playing audio: $e');
                      }
                    },
                  ),
              ],
            ),
            if (entry.phonetic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.phonetic,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey[600], fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 16),
            if (entry.partOfSpeech.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  entry.partOfSpeech,
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (entry.definition.isNotEmpty)
              Text(
                entry.definition,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // ignore: avoid_print
                  print('Đã lưu');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã lưu vào Sổ từ')),
                  );
                },
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Lưu vào Sổ từ/Flashcard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.article.content.isNotEmpty ? widget.article.content : widget.article.description;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.article.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.article.pubDate,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const Divider(height: 32, thickness: 1),
            SelectableText(
              displayText,
              style: const TextStyle(fontSize: 18, height: 1.6),
              onSelectionChanged: _onSelectionChanged,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'debounce.dart';
import 'translation_cache.dart';
import 'translation_service.dart';
import '../services/dictionary_service.dart';
import '../models/dictionary_entry_model.dart';

class TranslationViewModel extends ChangeNotifier {
  final TranslationService service;
  final DictionaryService dictionaryService = DictionaryService();
  final TranslationCache cache = TranslationCache();
  final Debouncer<String> _debouncer = Debouncer(delay: const Duration(milliseconds: 450));

  TranslationViewModel({required this.service}) {
    _debouncer.action = _performTranslate;
  }

  String? original;
  String? translated;
  String? explanation;
  String? error;
  bool isLoading = false;

  // New fields for single word lookup
  DictionaryEntry? dictionaryEntry;
  bool isSingleWord = false;

  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void requestTranslation({required String selected, required String context, String target = 'vi'}) {
    final words = selected.trim().split(RegExp(r'\s+'));
    isSingleWord = words.length == 1 && selected.trim().isNotEmpty;
    
    // Check cache first
    final cached = cache.get(selected, context);
    if (cached != null) {
      original = selected;
      translated = cached.translated;
      explanation = cached.explanation;
      error = null;
      // We still want to fetch dictionary info if it's a single word and not cached (or just fetch it)
      if (isSingleWord) {
        _fetchDictionaryInfo(selected);
      } else {
        dictionaryEntry = null;
        notifyListeners();
      }
      return;
    }

    // Debounce network calls
    _pendingSelected = selected;
    _pendingContext = context;
    _pendingTarget = target;
    _debouncer.call('');
  }

  String _pendingSelected = '';
  String _pendingContext = '';
  String _pendingTarget = 'vi';

  Future<void> _performTranslate(String _) async {
    final selected = _pendingSelected;
    final context = _pendingContext;
    final target = _pendingTarget;

    isLoading = true;
    error = null;
    dictionaryEntry = null;
    notifyListeners();

    try {
      // 1. Dịch text
      final res = await service.translate(selected: selected, context: context, target: target);
      original = selected;
      translated = res.translatedText;
      explanation = res.explanation;
      cache.set(selected, context, translated!, explanation);

      // 2. Nếu là 1 từ, lấy thêm thông tin từ điển
      if (isSingleWord) {
        try {
          dictionaryEntry = await dictionaryService.lookupWord(selected);
        } catch (e) {
          debugPrint('Dictionary lookup failed: $e');
          // Ko gán error vì bản dịch vẫn quan trọng hơn
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchDictionaryInfo(String word) async {
    try {
      dictionaryEntry = await dictionaryService.lookupWord(word);
      notifyListeners();
    } catch (e) {
      debugPrint('Dictionary lookup failed: $e');
    }
  }
}

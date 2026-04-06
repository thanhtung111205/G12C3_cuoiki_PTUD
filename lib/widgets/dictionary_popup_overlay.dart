import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/dictionary_entry_model.dart';
import '../services/dictionary_service.dart';
import '../utils/app_colors.dart';
import 'smart_save_bottom_sheet.dart';

typedef DictionaryPopupSaveCallback =
    void Function(BuildContext sheetContext, DictionaryEntry entry);

Future<void> showDictionaryPopupOverlay({
  required BuildContext context,
  required String word,
  required DictionaryService dictionaryService,
  required AudioPlayer audioPlayer,
  required DictionaryPopupSaveCallback onSave,
  VoidCallback? onLookupError,
  VoidCallback? onClosed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: FutureBuilder<DictionaryEntry>(
          future: dictionaryService.lookupWord(word),
          builder: (BuildContext _, AsyncSnapshot<DictionaryEntry> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _BottomSheetShell(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.deepPurple,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(sheetContext)) {
                  Navigator.pop(sheetContext);
                }
                final bool notFound =
                    snapshot.error is WordNotFoundException ||
                    snapshot.error.toString().contains('WordNotFoundException');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      notFound
                          ? 'Không tìm thấy nghĩa của "$word"'
                          : 'Lỗi tra từ điển: ${snapshot.error}',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                onLookupError?.call();
              });
              return const SizedBox.shrink();
            }

            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            return DictionaryPopupOverlay(
              entry: snapshot.data!,
              audioPlayer: audioPlayer,
              onSave: () {
                // Thay vì gọi callback cũ, ta mở bảng lưu thông minh kèm nghĩa
                Navigator.pop(sheetContext);
                showSmartSaveBottomSheet(
                  context,
                  word: snapshot.data!.word,
                  meaning: snapshot.data!.definition,
                );
              },
            );
          },
        ),
      );
    },
  ).whenComplete(() => onClosed?.call());
}

class DictionaryPopupOverlay extends StatelessWidget {
  const DictionaryPopupOverlay({
    super.key,
    required this.entry,
    required this.audioPlayer,
    required this.onSave,
  });

  final DictionaryEntry entry;
  final AudioPlayer audioPlayer;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return _BottomSheetShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.word,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (entry.audioUrl.isNotEmpty)
                  _AudioButton(audioUrl: entry.audioUrl, player: audioPlayer),
              ],
            ),
            if (entry.phonetic.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                entry.phonetic,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.periwinkle,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (entry.partOfSpeech.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.deepPurple.withValues(alpha: 0.3)
                      : AppColors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.partOfSpeech,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.periwinkle : AppColors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (entry.definition.isNotEmpty)
              Text(
                entry.definition,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: const Text('Lưu vào Sổ từ / Flashcard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AudioButton extends StatefulWidget {
  const _AudioButton({required this.audioUrl, required this.player});

  final String audioUrl;
  final AudioPlayer player;

  @override
  State<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<_AudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    _controller.forward().then((_) => _controller.reverse());
    try {
      await widget.player.play(UrlSource(widget.audioUrl));
    } catch (e) {
      debugPrint('Audio error: $e');
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.0,
        end: 0.85,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
      child: GestureDetector(
        onTap: _play,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.deepPurple.withValues(alpha: 0.12),
          ),
          child: Icon(
            _playing ? Icons.volume_up_rounded : Icons.play_circle_rounded,
            color: AppColors.deepPurple,
            size: 24,
          ),
        ),
      ),
    );
  }
}

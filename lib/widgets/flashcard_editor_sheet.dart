import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class FlashcardDraft {
  const FlashcardDraft({required this.english, required this.meaning});

  final String english;
  final String meaning;
}

const int kFlashcardMaxChars = 100;

class FlashcardEditorSheet extends StatefulWidget {
  const FlashcardEditorSheet({
    super.key,
    required this.title,
    required this.englishInitial,
    required this.meaningInitial,
  });

  final String title;
  final String englishInitial;
  final String meaningInitial;

  @override
  State<FlashcardEditorSheet> createState() => _FlashcardEditorSheetState();
}

class _FlashcardEditorSheetState extends State<FlashcardEditorSheet> {
  late final TextEditingController _englishController;
  late final TextEditingController _meaningController;
  bool _isSaving = false;
  String? _englishError;
  String? _meaningError;

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

    bool hasError = false;
    String? englishErr;
    String? meaningErr;

    if (english.isEmpty) {
      englishErr = 'Vui lòng nhập từ tiếng Anh.';
      hasError = true;
    } else if (english.length > kFlashcardMaxChars) {
      englishErr = 'Từ tiếng Anh không được quá $kFlashcardMaxChars ký tự.';
      hasError = true;
    }

    if (meaning.isEmpty) {
      meaningErr = 'Vui lòng nhập nghĩa tiếng Việt.';
      hasError = true;
    } else if (meaning.length > kFlashcardMaxChars) {
      meaningErr = 'Nghĩa không được quá $kFlashcardMaxChars ký tự.';
      hasError = true;
    }

    if (hasError) {
      setState(() {
        _englishError = englishErr;
        _meaningError = meaningErr;
      });
      return;
    }

    setState(() {
      _englishError = null;
      _meaningError = null;
      _isSaving = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (mounted) {
      Navigator.of(
        context,
      ).pop(FlashcardDraft(english: english, meaning: meaning));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color sheetBg = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final Color titleColor = isDark ? Colors.white : AppColors.deepPurple;
    final Color closeColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.lightTextSecondary;
    final Color fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.lavender.withValues(alpha: 0.45);
    final Color labelColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.lightTextSecondary;
    final Color inputColor = isDark ? Colors.white : AppColors.lightText;
    // final Color hintColor = isDark
    //     ? Colors.white.withValues(alpha: 0.76)
    //     : AppColors.periwinkle;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.lavender.withValues(alpha: 0.7),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.deepPurple)
                    .withValues(alpha: isDark ? 0.42 : 0.18),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: closeColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _englishController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSaving,
                      style: TextStyle(color: inputColor),
                      maxLength: kFlashcardMaxChars,
                      onChanged: (_) {
                        if (_englishError != null) {
                          setState(() => _englishError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Tiếng Anh',
                        labelStyle: TextStyle(color: labelColor),
                        filled: true,
                        fillColor: fieldFill,
                        errorText: _englishError,
                        errorMaxLines: 2,
                        counterStyle: TextStyle(
                          color: labelColor,
                          fontSize: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
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
                      style: TextStyle(color: inputColor),
                      maxLength: kFlashcardMaxChars,
                      onChanged: (_) {
                        if (_meaningError != null) {
                          setState(() => _meaningError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Nghĩa tiếng Việt',
                        labelStyle: TextStyle(color: labelColor),
                        filled: true,
                        fillColor: fieldFill,
                        errorText: _meaningError,
                        errorMaxLines: 2,
                        counterStyle: TextStyle(
                          color: labelColor,
                          fontSize: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    disabledBackgroundColor: AppColors.deepPurple.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.78,
                    ),
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

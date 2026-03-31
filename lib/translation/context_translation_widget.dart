import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'translation_viewmodel.dart';
import 'debounce.dart';
import '../widgets/smart_save_bottom_sheet.dart';
import '../utils/app_colors.dart';

/// Widget that displays selectable text and allows context-aware translation and quick save
class ContextTranslationWidget extends StatefulWidget {
  final String? text;
  final TextEditingController? controller;
  final TranslationViewModel viewModel;
  final bool readOnly;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final InputDecoration? decoration;
  final bool expands;
  final TextAlignVertical? textAlignVertical;

  const ContextTranslationWidget({
    super.key,
    this.text,
    this.controller,
    required this.viewModel,
    this.readOnly = true,
    this.style,
    this.maxLines,
    this.minLines,
    this.decoration,
    this.expands = false,
    this.textAlignVertical,
  });

  @override
  State<ContextTranslationWidget> createState() => _ContextTranslationWidgetState();
}

class _ContextTranslationWidgetState extends State<ContextTranslationWidget> {
  late final TextEditingController _internalController;
  TextEditingController get _controller => widget.controller ?? _internalController;

  late final FocusNode _focusNode;
  late final Debouncer<TextSelection> _selectionDebouncer;
  late final AudioPlayer _audioPlayer;
  bool _isBottomSheetOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController(text: widget.text);
    }
    _focusNode = FocusNode();
    _audioPlayer = AudioPlayer();
    _selectionDebouncer = Debouncer<TextSelection>(delay: const Duration(milliseconds: 600));
    _selectionDebouncer.action = (sel) {
      if (sel.isCollapsed || _isBottomSheetOpen) return;
      
      final full = _controller.text;
      final start = sel.start.clamp(0, full.length);
      final end = sel.end.clamp(0, full.length);
      if (start >= end) return;
      final selected = full.substring(start, end).trim();
      if (selected.isEmpty) return;
      
      // Tăng giới hạn tự động dịch lên 2000 kí tự để thoải mái hơn
      if (selected.length > 2000) return;

      final surrounding = _extractContext(full, sel);
      _openTranslationForSelection(context, selected, surrounding);
    };

    _controller.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() {
    final sel = _controller.selection;
    if (sel.isCollapsed) return;
    _selectionDebouncer.call(sel);
  }

  @override
  void didUpdateWidget(ContextTranslationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onSelectionChanged);
      widget.controller?.addListener(_onSelectionChanged);
    } else if (widget.controller == null && widget.text != oldWidget.text) {
      _internalController.text = widget.text ?? '';
    }
  }

  @override
  void dispose() {
    _selectionDebouncer.dispose();
    _controller.removeListener(_onSelectionChanged);
    if (widget.controller == null) {
      _internalController.dispose();
    }
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _extractContext(String fullText, TextSelection sel) {
    if (fullText.isEmpty) return '';
    final start = sel.start.clamp(0, fullText.length);
    final end = sel.end.clamp(0, fullText.length);
    
    // Giới hạn vùng tìm ngữ cảnh để tránh URL quá dài (MyMemory giới hạn)
    int lookBack = 250;
    int lookAhead = 250;
    
    int sLimit = (start - lookBack).clamp(0, fullText.length);
    int eLimit = (end + lookAhead).clamp(0, fullText.length);
    
    String sub = fullText.substring(sLimit, eLimit);
    int relStart = start - sLimit;
    int relEnd = end - sLimit;
    
    // Sửa lỗi lastIndexOf với index âm (crash khi bôi đen từ đầu câu)
    int s = 0;
    if (relStart > 0) {
      s = sub.lastIndexOf(RegExp(r'[\.\?!\n]'), relStart - 1);
      s = (s == -1) ? 0 : s + 1;
    }
    
    int e = sub.indexOf(RegExp(r'[\.\?!\n]'), relEnd);
    e = (e == -1) ? sub.length : e;
    
    return sub.substring(s, e).trim();
  }

  Future<void> _openTranslationForSelection(BuildContext hostContext, String selected, String surrounding) async {
    if (_isBottomSheetOpen) return;
    
    widget.viewModel.requestTranslation(selected: selected, context: surrounding);
    setState(() => _isBottomSheetOpen = true);
    
    await showModalBottomSheet<void>(
      context: hostContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(hostContext).brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, child) {
              final vm = widget.viewModel;
              if (vm.isLoading) {
                return SizedBox(
                  height: 250,
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [CircularProgressIndicator(color: AppColors.deepPurple), SizedBox(height: 12), Text('Đang xử lý...')])),
                );
              }
              if (vm.error != null) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 12),
                      const Text('Không thể dịch đoạn này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(vm.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                      ),
                    ],
                  ),
                );
              }

              final bool showDictionary = vm.isSingleWord && vm.dictionaryEntry != null;

              return Padding(
                padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.fromLTRB(24, 12, 24, 28)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tiêu đề (Từ đơn hoặc cụm từ)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vm.original ?? selected, 
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: showDictionary ? 24 : 18, color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
                              if (showDictionary && vm.dictionaryEntry!.phonetic.isNotEmpty)
                                Text(vm.dictionaryEntry!.phonetic, 
                                  style: const TextStyle(fontSize: 16, color: AppColors.periwinkle, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        if (showDictionary && vm.dictionaryEntry!.audioUrl.isNotEmpty)
                          _AudioButton(audioUrl: vm.dictionaryEntry!.audioUrl, player: _audioPlayer),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    Text(showDictionary ? 'Nghĩa của từ' : 'Bản dịch tiếng Việt', 
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 8),
                    
                    Text(vm.translated ?? '', 
                      style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
                    
                    if (showDictionary && vm.dictionaryEntry!.partOfSpeech.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(6)),
                        child: Text(vm.dictionaryEntry!.partOfSpeech, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepPurple)),
                      ),
                    ],

                    if ((vm.explanation ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Giải thích thêm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      const SizedBox(height: 4),
                      Text(vm.explanation ?? '', style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
                    ],
                    
                    const SizedBox(height: 28),
                    
                    // Button Save đồng bộ phong cách Main (Luôn dùng nút lớn có icon)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final wordToSave = vm.original ?? selected;
                          Navigator.of(hostContext).pop();
                          showSmartSaveBottomSheet(hostContext, word: wordToSave);
                        },
                        icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                        label: const Text('Lưu vào Sổ từ / Flashcard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    
    if (mounted) {
      setState(() => _isBottomSheetOpen = false);
      _controller.selection = const TextSelection.collapsed(offset: -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      textAlignVertical: widget.textAlignVertical,
      decoration: widget.decoration ?? const InputDecoration(border: InputBorder.none),
      style: widget.style ?? const TextStyle(fontSize: 16, height: 1.4),
      showCursor: !widget.readOnly,
      contextMenuBuilder: (context, editableTextState) {
        final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
        final selection = editableTextState.textEditingValue.selection;

        if (!selection.isCollapsed) {
          buttonItems.insert(0, ContextMenuButtonItem(
            label: 'Dịch',
            onPressed: () {
              final full = _controller.text;
              final selected = full.substring(selection.start, selection.end);
              final surrounding = _extractContext(full, selection);
              editableTextState.hideToolbar();
              _openTranslationForSelection(context, selected, surrounding);
            },
          ));
          buttonItems.insert(1, ContextMenuButtonItem(
            label: 'Lưu',
            onPressed: () {
              final full = _controller.text;
              final selected = full.substring(selection.start, selection.end).trim();
              editableTextState.hideToolbar();
              showSmartSaveBottomSheet(context, word: selected);
            },
          ));
        }

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
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

class _AudioButtonState extends State<_AudioButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
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
      scale: Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
      child: GestureDetector(
        onTap: _play,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.deepPurple.withOpacity(0.1)),
          child: Icon(_playing ? Icons.volume_up_rounded : Icons.play_circle_rounded, color: AppColors.deepPurple, size: 26),
        ),
      ),
    );
  }
}

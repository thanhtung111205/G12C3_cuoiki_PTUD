import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../translation/context_translation_widget.dart';
import '../../translation/translation_service.dart';
import '../../translation/translation_viewmodel.dart';

class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({super.key, this.document, this.initialContent});

  final DocumentModel? document;
  final String? initialContent;

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late DocumentProvider _documentProvider;
  late final TranslationViewModel _translationViewModel;
  List<String> _tags = <String>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _documentProvider = DocumentProvider.instance;

    _titleController = TextEditingController(text: widget.document?.title ?? '');
    _contentController = TextEditingController(
        text: widget.document?.content ?? widget.initialContent ?? '');
    _tagController = TextEditingController();
    _tags = List<String>.from(widget.document?.tags ?? []);
    
    _translationViewModel = TranslationViewModel(
      service: TranslationService(endpoint: 'https://api.mymemory.translated.net/get'),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _translationViewModel.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pasteContent() async {
    try {
      final ClipboardData? data = await Clipboard.getData('text/plain');
      if (data != null && data.text != null) {
        setState(() {
          _contentController.text += (_contentController.text.isEmpty ? '' : '\n') + data.text!;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã dán nội dung thành công'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi dán nội dung: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveDocument() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề tài liệu'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung tài liệu'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.document == null) {
        // Create new document
        await _documentProvider.createDocument(
          title: title,
          content: content,
          tags: _tags,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài liệu đã được tạo thành công'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Update existing document
        await _documentProvider.updateDocument(
          documentId: widget.document!.id,
          title: title,
          content: content,
          tags: _tags,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài liệu đã được cập nhật thành công'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.document != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa Tài liệu' : 'Tạo Tài liệu mới'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Field
            Text(
              'Tiêu đề',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Nhập tiêu đề tài liệu',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 24),

            // Content Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nội dung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pasteContent,
                  icon: const Icon(Icons.paste, size: 18),
                  label: const Text('Dán'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ContextTranslationWidget(
                controller: _contentController,
                viewModel: _translationViewModel,
                readOnly: false,
                maxLines: 12,
                minLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Nhập nội dung hoặc dán từ bên ngoài',
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tags Section
            Text(
              'Thẻ (Tags)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: 'Nhập thẻ và nhấn Thêm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addTag,
                  child: const Text('Thêm'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Display tags
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: colorScheme.primary,
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveDocument,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(isEditing ? 'Cập nhật' : 'Tạo mới'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

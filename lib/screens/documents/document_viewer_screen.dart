import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import 'document_editor_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.document});

  final DocumentModel document;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late DocumentProvider _documentProvider;

  @override
  void initState() {
    super.initState();
    _documentProvider = DocumentProvider.instance;
  }

  void _onEdit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentEditorScreen(document: widget.document),
      ),
    ).then((_) {
      // After edit, pop back to list to refresh
      Navigator.pop(context);
    });
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
                  // Show success message first
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tài liệu đã được xóa thành công'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  // Wait a moment then pop back to list
                  await Future.delayed(const Duration(milliseconds: 500));
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

  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng chia sẻ sẽ được cập nhật sớm'),
        duration: Duration(seconds: 2),
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
        title: const Text('Xem Tài Liệu'),
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
            icon: const Icon(Icons.share),
            onPressed: _onShare,
            tooltip: 'Chia sẻ',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _onDelete,
            tooltip: 'Xóa',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Title
            Text(
              widget.document.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Document Info
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
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
              const SizedBox(height: 16),
            ],

            // Divider
            Divider(
              color: colorScheme.outline.withOpacity(0.2),
            ),
            const SizedBox(height: 16),

            // Document Content
            Text(
              'Nội dung',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.5),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.document.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
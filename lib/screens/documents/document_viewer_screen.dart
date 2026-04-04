import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/document_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/document_provider.dart';
import '../../translation/context_translation_widget.dart';
import '../../translation/translation_service.dart';
import '../../translation/translation_viewmodel.dart';
import 'document_editor_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.document});

  final DocumentModel document;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late DocumentProvider _documentProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatProvider _chatProvider = ChatProvider.instance;
  late TextEditingController _contentController;
  late TranslationViewModel _translationViewModel;

  @override
  void initState() {
    super.initState();
    _documentProvider = DocumentProvider.instance;
    _contentController = TextEditingController(text: widget.document.content);
    _translationViewModel = TranslationViewModel(
      service: TranslationService(
        endpoint: 'https://api.mymemory.translated.net/get',
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _translationViewModel.dispose();
    super.dispose();
  }

  void _onEdit() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => DocumentEditorScreen(document: widget.document),
          ),
        )
        .then((_) {
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

  Future<void> _onShare() async {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chia sẻ tài liệu.')),
      );
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> roomSnapshot = await _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .get();

    final Set<String> partnerIds = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> roomDoc
        in roomSnapshot.docs) {
      final Map<String, dynamic> roomData = roomDoc.data();
      final String lastMessage = (roomData['lastMessage'] as String? ?? '')
          .trim();
      if (lastMessage.isEmpty) {
        continue;
      }

      final List<String> participants = List<String>.from(
        roomData['participants'] ?? <String>[],
      );
      if (!participants.contains(currentUserId)) {
        continue;
      }

      final String? partnerId = participants.cast<String?>().firstWhere(
        (String? id) => id != null && id != currentUserId,
        orElse: () => null,
      );
      if (partnerId != null && partnerId.isNotEmpty) {
        partnerIds.add(partnerId);
      }
    }

    final List<DocumentSnapshot<Map<String, dynamic>>> userDocs =
        await Future.wait(
          partnerIds.map(
            (String id) => _firestore.collection('users').doc(id).get(),
          ),
        );

    final List<_SharePeer> peers = userDocs
        .where((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists)
        .map((DocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
          final String name =
              (data['displayName'] as String?)?.trim().isNotEmpty == true
              ? (data['displayName'] as String).trim()
              : (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : (data['email'] as String?)?.split('@').first ?? 'Bạn học';

          return _SharePeer(
            id: doc.id,
            name: name,
            avatarUrl:
                data['avatarUrl'] as String? ?? data['photoUrl'] as String?,
          );
        })
        .toList();

    if (!mounted) return;

    if (peers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chỉ có thể chia sẻ cho bạn học đã từng nhắn tin.'),
        ),
      );
      return;
    }

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final _SharePeer? selectedPeer = await showModalBottomSheet<_SharePeer>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      builder: (BuildContext sheetContext) {
        final ThemeData sheetTheme = Theme.of(sheetContext);
        final Color sheetTextColor = sheetTheme.colorScheme.onSurface;
        final Color sheetSubtleColor = sheetTheme.colorScheme.onSurface
            .withValues(alpha: 0.72);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chia sẻ cho bạn học',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: sheetTextColor,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: peers.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: sheetSubtleColor.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final _SharePeer peer = peers[index];
                    return ListTile(
                      tileColor: Colors.transparent,
                      leading: CircleAvatar(
                        backgroundColor:
                            sheetTheme.colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            peer.avatarUrl?.trim().isNotEmpty == true
                            ? NetworkImage(peer.avatarUrl!)
                            : null,
                        child: peer.avatarUrl?.trim().isNotEmpty == true
                            ? null
                            : Icon(Icons.person, color: sheetTextColor),
                      ),
                      title: Text(
                        peer.name,
                        style: TextStyle(color: sheetTextColor),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: sheetSubtleColor,
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(peer),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedPeer == null) return;

    final String payload =
        'DOC_SHARE::${jsonEncode(<String, dynamic>{'type': 'document_share', 'documentId': widget.document.id, 'title': widget.document.title, 'content': widget.document.content, 'wordCount': widget.document.wordCount, 'sharedBy': currentUserId, 'sharedAt': DateTime.now().toIso8601String()})}';

    final String roomId = await _chatProvider.ensureRoom(
      currentUserId: currentUserId,
      partnerId: selectedPeer.id,
    );

    await _chatProvider.sendMessage(
      roomId: roomId,
      senderId: currentUserId,
      receiverId: selectedPeer.id,
      content: payload,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã chia sẻ tài liệu cho ${selectedPeer.name}')),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

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
                  color: colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.82 : 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.document.wordCount} từ • Cập nhật: ${_formatDate(widget.document.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.82 : 0.6,
                      ),
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
            Divider(color: colorScheme.outline.withOpacity(0.2)),
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
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ContextTranslationWidget(
                controller: _contentController,
                viewModel: _translationViewModel,
                readOnly: true,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                maxLines: null,
                expands: false,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SharePeer {
  const _SharePeer({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/chat_message_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.currentUserId,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.initialRoomId,
  });

  final String currentUserId;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? initialRoomId;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatProvider _chatProvider = ChatProvider.instance;
  final TextEditingController _messageController = TextEditingController();

  String? _roomId;
  String? _lastSeenMessageId;
  bool _isRoomLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _bootstrapRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapRoom() async {
    try {
      final String roomId =
          widget.initialRoomId ??
          await _chatProvider.ensureRoom(
            currentUserId: widget.currentUserId,
            partnerId: widget.partnerId,
          );

      if (!mounted) return;
      setState(() {
        _roomId = roomId;
        _isRoomLoading = false;
      });
      await _chatProvider.markRoomAsRead(
        roomId: roomId,
        currentUserId: widget.currentUserId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRoomLoading = false;
      });
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  ChatMessageModel? _latestOutgoingMessage(List<ChatMessageModel> messages) {
    for (final ChatMessageModel message in messages) {
      if (message.senderId == widget.currentUserId) {
        return message;
      }
    }
    return null;
  }

  _SharedDocumentPayload? _tryParseSharedDocument(String raw) {
    if (raw.startsWith('DOC_SHARE::')) {
      try {
        final String jsonPart = raw.substring('DOC_SHARE::'.length);
        final Map<String, dynamic> map =
            jsonDecode(jsonPart) as Map<String, dynamic>;
        return _SharedDocumentPayload(
          documentId: map['documentId'] as String? ?? '',
          title: map['title'] as String? ?? 'Tài liệu được chia sẻ',
          content: map['content'] as String? ?? '',
          wordCount: map['wordCount'] as int? ?? 0,
          sharedBy: map['sharedBy'] as String? ?? '',
          sharedAt: DateTime.tryParse(map['sharedAt'] as String? ?? ''),
        );
      } catch (_) {
        return null;
      }
    }

    if (!raw.startsWith('📄 Tài liệu được chia sẻ')) return null;
    final List<String> lines = raw.split('\n');
    final String title = lines
        .firstWhere(
          (e) => e.startsWith('Tiêu đề:'),
          orElse: () => 'Tiêu đề: Tài liệu',
        )
        .replaceFirst('Tiêu đề:', '')
        .trim();
    final String preview = lines
        .firstWhere(
          (e) => e.startsWith('Nội dung tóm tắt:'),
          orElse: () => 'Nội dung tóm tắt:',
        )
        .replaceFirst('Nội dung tóm tắt:', '')
        .trim();
    final String wordRaw = lines
        .firstWhere((e) => e.startsWith('Từ:'), orElse: () => 'Từ: 0')
        .replaceFirst('Từ:', '')
        .trim();

    return _SharedDocumentPayload(
      documentId: '',
      title: title,
      content: preview,
      wordCount: int.tryParse(wordRaw) ?? 0,
      sharedBy: '',
      sharedAt: null,
    );
  }

  void _handleIncomingSignals(List<ChatMessageModel> messages) {
    if (messages.isEmpty) return;
    final ChatMessageModel latest = messages.first;

    if (_lastSeenMessageId == null) {
      _lastSeenMessageId = latest.id;
      return;
    }

    if (_lastSeenMessageId == latest.id) return;
    _lastSeenMessageId = latest.id;

    if (latest.senderId != widget.currentUserId) {
      final _SharedDocumentPayload? sharedDoc = _tryParseSharedDocument(
        latest.content,
      );
      NotificationService.instance.playIncomingMessageSound(
        eventKey: '${_roomId ?? 'room'}:${latest.id}',
        title: 'Tin nhắn mới từ ${widget.partnerName}',
        body: sharedDoc != null
            ? 'Đã chia sẻ tài liệu: ${sharedDoc.title}'
            : latest.content,
      );
      if (_roomId != null) {
        _chatProvider.markRoomAsRead(
          roomId: _roomId!,
          currentUserId: widget.currentUserId,
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final String content = _messageController.text.trim();
    if (content.isEmpty || _roomId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _chatProvider.sendMessage(
        roomId: _roomId!,
        senderId: widget.currentUserId,
        receiverId: widget.partnerId,
        content: content,
      );
      _messageController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể gửi tin nhắn: $error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color pageBackground =
        isDark ? AppColors.darkBackground : Colors.white;
    final Color primaryText = isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color inputFill = isDark ? AppColors.darkCard : const Color(0xFFF5F3FB);

    if (_isRoomLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_roomId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Không thể mở phòng chat. Vui lòng thử lại.',
            style: TextStyle(color: AppColors.lightTextSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: primaryText,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.lavender,
              backgroundImage:
                  widget.partnerAvatarUrl?.trim().isNotEmpty == true
                  ? NetworkImage(widget.partnerAvatarUrl!)
                  : null,
              child: widget.partnerAvatarUrl?.trim().isNotEmpty == true
                  ? null
                  : const Icon(Icons.person, color: AppColors.deepPurple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    widget.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  Text(
                    'Đang hoạt động',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatProvider.streamMessages(_roomId!),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<ChatMessageModel>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Không thể tải tin nhắn: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: secondaryText),
                          ),
                        ),
                      );
                    }

                    final List<ChatMessageModel> messages =
                        snapshot.data ?? <ChatMessageModel>[];
                    final ChatMessageModel? latestOutgoing =
                        _latestOutgoingMessage(messages);
                    _handleIncomingSignals(messages);

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có tin nhắn nào. Hãy gửi lời chào đầu tiên!',
                          style: TextStyle(color: AppColors.lightTextSecondary),
                        ),
                      );
                    }

                    return Column(
                      children: <Widget>[
                        Expanded(
                          child: ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                            itemCount: messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ChatMessageModel message = messages[index];
                              final bool isMe =
                                  message.senderId == widget.currentUserId;
                              final _SharedDocumentPayload? sharedDoc =
                                  _tryParseSharedDocument(message.content);

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.76,
                                  ),
                                  child: GestureDetector(
                                    onTap: sharedDoc == null
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    _SharedDocumentPreviewScreen(
                                                      payload: sharedDoc,
                                                    ),
                                              ),
                                            );
                                          },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.deepPurple
                                            : (isDark
                                                ? AppColors.darkCard
                                                : AppColors.lavender),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(
                                            isMe ? 16 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 4 : 16,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          if (sharedDoc != null)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: <Widget>[
                                                    Icon(
                                                      Icons.description_rounded,
                                                      size: 16,
                                                      color: isMe
                                                          ? Colors.white
                                                        : (isDark
                                                          ? AppColors.periwinkle
                                                          : AppColors.deepPurple),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Tài liệu được chia sẻ',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isMe
                                                            ? Colors.white
                                                          : (isDark
                                                            ? AppColors.darkText
                                                            : AppColors.lightText),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  sharedDoc.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: isMe
                                                        ? Colors.white
                                                      : (isDark
                                                        ? AppColors.darkText
                                                        : AppColors.lightText),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Từ: ${sharedDoc.wordCount}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isMe
                                                        ? Colors.white70
                                                      : (isDark
                                                        ? AppColors.darkTextSecondary
                                                        : AppColors.lightTextSecondary),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  'Nhấn để xem tài liệu',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: isMe
                                                        ? Colors.white70
                                                      : (isDark
                                                        ? AppColors.darkTextSecondary
                                                        : AppColors.lightTextSecondary),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              message.content,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.35,
                                                color: isMe
                                                    ? Colors.white
                                                  : (isDark
                                                    ? AppColors.darkText
                                                    : AppColors.lightText),
                                                fontWeight: isMe
                                                    ? FontWeight.w500
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          const SizedBox(height: 5),
                                          Text(
                                            _formatMessageTime(
                                              message.timestamp,
                                            ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white70
                                                  : (isDark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors.lightTextSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (latestOutgoing != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 18, 6),
                              child: Text(
                                latestOutgoing.isRead ? 'Đã xem' : 'Đã gửi',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedDocumentPayload {
  const _SharedDocumentPayload({
    required this.documentId,
    required this.title,
    required this.content,
    required this.wordCount,
    required this.sharedBy,
    required this.sharedAt,
  });

  final String documentId;
  final String title;
  final String content;
  final int wordCount;
  final String sharedBy;
  final DateTime? sharedAt;
}

class _SharedDocumentPreviewScreen extends StatelessWidget {
  const _SharedDocumentPreviewScreen({required this.payload});

  final _SharedDocumentPayload payload;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color pageBackground =
        isDark ? AppColors.darkBackground : Colors.white;
    final Color primaryText = isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu được chia sẻ'),
        backgroundColor: pageBackground,
        foregroundColor: primaryText,
      ),
      backgroundColor: pageBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              payload.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Số từ: ${payload.wordCount}',
              style: TextStyle(color: secondaryText, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF8F6FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                payload.content.trim().isEmpty
                    ? 'Tài liệu chia sẻ không có nội dung hiển thị.'
                    : payload.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

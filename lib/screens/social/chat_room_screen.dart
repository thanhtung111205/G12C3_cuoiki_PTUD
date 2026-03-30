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
      NotificationService.instance.playIncomingMessageSound(
        eventKey: '${_roomId ?? 'room'}:${latest.id}',
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightText,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Đang hoạt động',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.lightTextSecondary,
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
                            style: const TextStyle(
                              color: AppColors.lightTextSecondary,
                            ),
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
                                          : AppColors.lavender,
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
                                        Text(
                                          message.content,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.35,
                                            color: isMe
                                                ? Colors.white
                                                : AppColors.lightText,
                                            fontWeight: isMe
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _formatMessageTime(message.timestamp),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white70
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
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
                        fillColor: const Color(0xFFF5F3FB),
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

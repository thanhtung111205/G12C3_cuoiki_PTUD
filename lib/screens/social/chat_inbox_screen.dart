import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import 'chat_room_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ChatProvider _chatProvider = ChatProvider.instance;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _previousUnreadCounts = <String, int>{};

  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _buildPreviewText(String? raw) {
    final String message = raw?.trim() ?? '';
    if (message.isEmpty) {
      return 'Bắt đầu trò chuyện ngay';
    }

    if (message.startsWith('DOC_SHARE::')) {
      try {
        final Map<String, dynamic> map =
            jsonDecode(message.substring('DOC_SHARE::'.length))
                as Map<String, dynamic>;
        final String title = map['title'] as String? ?? 'Tài liệu';
        return '📄 Đã chia sẻ tài liệu: $title';
      } catch (_) {
        return '📄 Đã chia sẻ tài liệu';
      }
    }

    if (message.startsWith('📄 Tài liệu được chia sẻ')) {
      return '📄 Đã chia sẻ tài liệu';
    }

    return message;
  }

  void _maybePlayIncomingSound(List<ChatInboxItem> items) {
    bool shouldPlay = false;

    for (final ChatInboxItem item in items) {
      final int previous =
          _previousUnreadCounts[item.roomId] ?? item.unreadCount;
      if (item.unreadCount > previous) {
        shouldPlay = true;
      }
      _previousUnreadCounts[item.roomId] = item.unreadCount;
    }

    if (shouldPlay) {
      final ChatInboxItem newestItem = items.first;
      final String eventKey =
          '${newestItem.roomId}:${newestItem.lastMessageTime?.millisecondsSinceEpoch ?? 0}:${newestItem.unreadCount}';
      NotificationService.instance.playIncomingMessageSound(
        eventKey: eventKey,
        title: 'Tin nhắn mới từ ${newestItem.partnerName}',
        body: _buildPreviewText(newestItem.lastMessage),
      );
    }
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final DateTime now = DateTime.now();
    final bool sameDay =
        now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;

    if (sameDay) {
      return DateFormat('HH:mm').format(dateTime);
    }

    return DateFormat('dd/MM').format(dateTime);
  }

  List<ChatInboxItem> _applySearch(List<ChatInboxItem> items) {
    final String query = _keyword.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items
        .where(
          (ChatInboxItem item) =>
              item.partnerName.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Bạn cần đăng nhập để sử dụng hộp thư.',
            style: TextStyle(fontSize: 15, color: AppColors.lightTextSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCFBFF),
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightText,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (String value) {
                  setState(() {
                    _keyword = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bạn học...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF4F2FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatInboxItem>>(
                stream: _chatProvider.streamInboxItems(currentUserId),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<ChatInboxItem>> snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Không thể tải hộp thư: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        );
                      }

                      final List<ChatInboxItem> sourceItems =
                          snapshot.data ?? <ChatInboxItem>[];
                      _maybePlayIncomingSound(sourceItems);

                      final List<ChatInboxItem> items = _applySearch(
                        sourceItems,
                      );

                      if (sourceItems.isEmpty) {
                        return const _InboxEmptyState(
                          title: 'Chưa có cuộc trò chuyện',
                          subtitle:
                              'Hãy mở Bản đồ Bạn học và bắt đầu trò chuyện với một bạn học ở gần bạn.',
                        );
                      }

                      if (items.isEmpty) {
                        return const _InboxEmptyState(
                          title: 'Không tìm thấy kết quả',
                          subtitle: 'Hãy thử lại với từ khóa khác.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final ChatInboxItem item = items[index];
                          final bool unread = item.unreadCount > 0;

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChatRoomScreen(
                                      currentUserId: currentUserId,
                                      partnerId: item.partnerId,
                                      partnerName: item.partnerName,
                                      partnerAvatarUrl: item.partnerAvatarUrl,
                                      initialRoomId: item.roomId,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: AppColors.lavender,
                                      backgroundImage:
                                          item.partnerAvatarUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? NetworkImage(item.partnerAvatarUrl!)
                                          : null,
                                      child:
                                          item.partnerAvatarUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? null
                                          : const Icon(
                                              Icons.person_rounded,
                                              color: AppColors.deepPurple,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.partnerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.lightText,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            _buildPreviewText(item.lastMessage),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: unread
                                                  ? AppColors.lightText
                                                  : AppColors
                                                        .lightTextSecondary,
                                              fontWeight: unread
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Text(
                                          _formatTimestamp(
                                            item.lastMessageTime,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.lightTextSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (unread)
                                          Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 22,
                                              minHeight: 22,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE53935),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              item.unreadCount > 99
                                                  ? '99+'
                                                  : '${item.unreadCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          )
                                        else
                                          const SizedBox(height: 22),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.mark_chat_read_rounded,
              size: 56,
              color: AppColors.periwinkle,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

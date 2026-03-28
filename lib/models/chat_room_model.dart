import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;

  const ChatRoomModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
  });

  ChatRoomModel copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCount,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ChatRoomModel(
      id: documentId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageTime != null)
        'lastMessageTime': Timestamp.fromDate(lastMessageTime!),
      'unreadCount': unreadCount,
    };
  }
}

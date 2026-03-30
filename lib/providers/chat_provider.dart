import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message_model.dart';
import '../models/chat_room_model.dart';

class ChatInboxItem {
  const ChatInboxItem({
    required this.roomId,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.partnerStatus,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
  });

  final String roomId;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? partnerStatus;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
}

class ChatProvider extends ChangeNotifier {
  ChatProvider._();

  static final ChatProvider instance = ChatProvider._();

  factory ChatProvider() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatRoomsRef =>
      _firestore.collection('chatRooms');

  String roomIdForUsers(String userA, String userB) {
    final List<String> participants = <String>[userA, userB]..sort();
    return '${participants[0]}_${participants[1]}';
  }

  Future<String> ensureRoom({
    required String currentUserId,
    required String partnerId,
  }) async {
    final String roomId = roomIdForUsers(currentUserId, partnerId);
    final DocumentReference<Map<String, dynamic>> roomRef = _chatRoomsRef.doc(
      roomId,
    );

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> roomSnap = await transaction
          .get(roomRef);

      if (roomSnap.exists) {
        final List<String> participants = List<String>.from(
          roomSnap.data()?['participants'] ?? <String>[],
        );
        if (participants.contains(currentUserId) &&
            participants.contains(partnerId)) {
          return;
        }
      }

      transaction.set(roomRef, <String, dynamic>{
        'participants': <String>[currentUserId, partnerId],
        'unreadCount': <String, int>{currentUserId: 0, partnerId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return roomId;
  }

  Stream<List<ChatMessageModel>> streamMessages(String roomId) {
    return _chatRoomsRef
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    ChatMessageModel.fromMap(doc.data(), doc.id),
              )
              .toList();
        });
  }

  Stream<List<ChatInboxItem>> streamInboxItems(String currentUserId) {
    return _chatRoomsRef
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
          final List<ChatRoomModel> rooms = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    ChatRoomModel.fromMap(doc.data(), doc.id),
              )
              .toList();

          rooms.sort((ChatRoomModel a, ChatRoomModel b) {
            final DateTime aTime =
                a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final DateTime bTime =
                b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          if (rooms.isEmpty) return <ChatInboxItem>[];

          final Set<String> partnerIds = rooms
              .map(
                (ChatRoomModel room) => room.participants.firstWhere(
                  (String id) => id != currentUserId,
                ),
              )
              .toSet();

          final List<DocumentSnapshot<Map<String, dynamic>>> partnerDocs =
              await Future.wait(
                partnerIds.map(
                  (String id) => _firestore.collection('users').doc(id).get(),
                ),
              );

          final Map<String, Map<String, dynamic>> partnerDataById =
              <String, Map<String, dynamic>>{};
          for (final DocumentSnapshot<Map<String, dynamic>> doc
              in partnerDocs) {
            partnerDataById[doc.id] = doc.data() ?? <String, dynamic>{};
          }

          return rooms.map((ChatRoomModel room) {
            final String partnerId = room.participants.firstWhere(
              (String id) => id != currentUserId,
            );
            final Map<String, dynamic> partnerData =
                partnerDataById[partnerId] ?? <String, dynamic>{};

            final String partnerName =
                (partnerData['displayName'] as String?)?.trim().isNotEmpty ==
                    true
                ? (partnerData['displayName'] as String).trim()
                : (partnerData['name'] as String?)?.trim().isNotEmpty == true
                ? (partnerData['name'] as String).trim()
                : (partnerData['email'] as String?)?.split('@').first ??
                      'Bạn học';

            return ChatInboxItem(
              roomId: room.id,
              partnerId: partnerId,
              partnerName: partnerName,
              partnerAvatarUrl:
                  partnerData['avatarUrl'] as String? ??
                  partnerData['photoUrl'] as String?,
              partnerStatus:
                  partnerData['study_status'] as String? ??
                  ((partnerData['isOnline'] as bool?) == true
                      ? 'Đang online'
                      : 'Ngoại tuyến'),
              lastMessage: room.lastMessage,
              lastMessageTime: room.lastMessageTime,
              unreadCount: room.unreadCount[currentUserId] ?? 0,
            );
          }).toList();
        });
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final String cleanContent = content.trim();
    if (cleanContent.isEmpty) return;

    final DocumentReference<Map<String, dynamic>> roomRef = _chatRoomsRef.doc(
      roomId,
    );
    final DocumentReference<Map<String, dynamic>> messageRef = roomRef
        .collection('messages')
        .doc();

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> roomSnap = await transaction
          .get(roomRef);
      final Map<String, dynamic> currentData =
          roomSnap.data() ?? <String, dynamic>{};

      final Map<String, int> unreadCount = Map<String, int>.from(
        currentData['unreadCount'] ?? <String, int>{},
      );
      unreadCount[senderId] = 0;
      unreadCount[receiverId] = (unreadCount[receiverId] ?? 0) + 1;

      transaction.set(messageRef, <String, dynamic>{
        'roomId': roomId,
        'senderId': senderId,
        'content': cleanContent,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      transaction.set(roomRef, <String, dynamic>{
        'participants': <String>[senderId, receiverId],
        'lastMessage': cleanContent,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': unreadCount,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!roomSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> markRoomAsRead({
    required String roomId,
    required String currentUserId,
  }) async {
    final DocumentReference<Map<String, dynamic>> roomRef = _chatRoomsRef.doc(
      roomId,
    );

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> roomSnap = await transaction
          .get(roomRef);
      if (!roomSnap.exists) return;

      final Map<String, int> unreadCount = Map<String, int>.from(
        roomSnap.data()?['unreadCount'] ?? <String, int>{},
      );
      if ((unreadCount[currentUserId] ?? 0) > 0) {
        unreadCount[currentUserId] = 0;
        transaction.set(roomRef, <String, dynamic>{
          'unreadCount': unreadCount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    // Mark inbound unread messages as read so sender can see "Da xem" state.
    final QuerySnapshot<Map<String, dynamic>> unreadSnapshot = await roomRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .limit(120)
        .get();

    final WriteBatch batch = _firestore.batch();
    bool hasUpdates = false;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in unreadSnapshot.docs) {
      final String senderId = doc.data()['senderId'] as String? ?? '';
      if (senderId.isEmpty || senderId == currentUserId) {
        continue;
      }

      batch.update(doc.reference, <String, dynamic>{'isRead': true});
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }
}

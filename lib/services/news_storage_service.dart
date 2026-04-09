import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bookmark_model.dart';
import '../models/read_history_model.dart';

class NewsStorageService {
  NewsStorageService._();
  static final NewsStorageService instance = NewsStorageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the reference to the user's document
  DocumentReference _userDoc(String userId) =>
      _firestore.collection('users').doc(userId);

  /// Encode an arbitrary string (e.g. a URL) into a Firestore-safe document ID.
  /// Firestore document IDs must not contain '/' characters.
  String _safeId(String id) => base64UrlEncode(utf8.encode(id));

  /// Reverse of [_safeId] – used when reading document IDs back from Firestore.
  String _originalId(String safeId) =>
      utf8.decode(base64Url.decode(base64Url.normalize(safeId)));

  // ── Read History ─────────────────────────────────────────────────────────

  /// Stream of Set<String> containing all article IDs the user has read
  Stream<Set<String>> getReadArticlesStream(String userId) {
    return _userDoc(userId).collection('read_history').snapshots().map((qs) {
      // Decode each document ID back to the original articleId (URL/guid).
      return qs.docs.map((doc) {
        try {
          return _originalId(doc.id);
        } catch (_) {
          return doc.id; // fallback for any legacy un-encoded documents
        }
      }).toSet();
    });
  }

  /// Mark an article as read
  Future<void> markAsRead(String userId, String articleId) async {
    // Encode the articleId so URLs (containing '/') are safe as a Firestore document ID.
    final ref = _userDoc(userId).collection('read_history').doc(_safeId(articleId));
    await ref.set(
      ReadHistoryModel(
        id: articleId,
        readAt: DateTime.now(),
      ).toMap(),
    );
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  /// Stream of Map<String, BookmarkModel> containing all user's bookmarks
  Stream<Map<String, BookmarkModel>> getBookmarksStream(String userId) {
    return _userDoc(userId).collection('bookmarks').snapshots().map((qs) {
      final Map<String, BookmarkModel> map = {};
      for (final doc in qs.docs) {
        // The document ID is base64-encoded; decode it to get the original articleId.
        String originalArticleId;
        try {
          originalArticleId = _originalId(doc.id);
        } catch (_) {
          originalArticleId = doc.id; // fallback for legacy un-encoded documents
        }
        final bookmark = BookmarkModel.fromMap(doc.data(), originalArticleId);
        map[originalArticleId] = bookmark;
      }
      return map;
    });
  }

  /// Add a bookmark
  Future<void> addBookmark(String userId, BookmarkModel bookmark) async {
    final ref = _userDoc(userId).collection('bookmarks').doc(_safeId(bookmark.articleId));
    await ref.set(bookmark.toMap());
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String userId, String articleId) async {
    final ref = _userDoc(userId).collection('bookmarks').doc(_safeId(articleId));
    await ref.delete();
  }
}

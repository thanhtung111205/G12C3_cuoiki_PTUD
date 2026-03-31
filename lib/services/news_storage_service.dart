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

  // ── Read History ─────────────────────────────────────────────────────────

  /// Stream of Set<String> containing all article IDs the user has read
  Stream<Set<String>> getReadArticlesStream(String userId) {
    return _userDoc(userId).collection('read_history').snapshots().map((qs) {
      return qs.docs.map((doc) => doc.id).toSet();
    });
  }

  /// Mark an article as read
  Future<void> markAsRead(String userId, String articleId) async {
    final ref = _userDoc(userId).collection('read_history').doc(articleId);
    // Use SetOptions(merge:true) to avoid overwriting readAt if it already exists,
    // though here we might just want to update it to the latest time anyway.
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
        map[doc.id] = BookmarkModel.fromMap(doc.data(), doc.id);
      }
      return map;
    });
  }

  /// Add a bookmark
  Future<void> addBookmark(String userId, BookmarkModel bookmark) async {
    final ref = _userDoc(userId).collection('bookmarks').doc(bookmark.articleId);
    await ref.set(bookmark.toMap());
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String userId, String articleId) async {
    final ref = _userDoc(userId).collection('bookmarks').doc(articleId);
    await ref.delete();
  }
}

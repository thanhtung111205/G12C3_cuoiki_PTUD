import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/document_model.dart';

class DocumentProvider extends ChangeNotifier {
  DocumentProvider._();

  static final DocumentProvider instance = DocumentProvider._();

  factory DocumentProvider() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<DocumentModel> _documents = <DocumentModel>[];
  List<DocumentModel> _searchResults = <DocumentModel>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<DocumentModel> get documents => _documents;

  List<DocumentModel> get searchResults => _searchResults;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> fetchDocuments() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _documents = <DocumentModel>[];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final snapshot = await _firestore
          .collection('documents')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      _documents = snapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by updatedAt in descending order (most recent first)
      _documents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createDocument({
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');

      final now = DateTime.now();
      final wordCount = _calculateWordCount(content);

      final docRef = await _firestore.collection('documents').add({
        'userId': currentUser.uid,
        'title': title,
        'content': content,
        'tags': tags,
        'wordCount': wordCount,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      await fetchDocuments();
      return docRef.id;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDocument({
    required String documentId,
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');

      final wordCount = _calculateWordCount(content);

      await _firestore.collection('documents').doc(documentId).update({
        'title': title,
        'content': content,
        'tags': tags,
        'wordCount': wordCount,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await fetchDocuments();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      await _firestore.collection('documents').doc(documentId).delete();
      await fetchDocuments();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<DocumentModel?> getDocumentById(String documentId) async {
    try {
      final snapshot = await _firestore
          .collection('documents')
          .doc(documentId)
          .get();

      if (snapshot.exists) {
        return DocumentModel.fromMap(snapshot.data()!, documentId);
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> searchDocuments(String query) async {
    if (query.isEmpty) {
      _searchResults = <DocumentModel>[];
      notifyListeners();
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _searchResults = <DocumentModel>[];
        notifyListeners();
        return;
      }

      final snapshot = await _firestore
          .collection('documents')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final documents = snapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.data(), doc.id))
          .toList();

      // Filter by title or content (case-insensitive)
      final queryLower = query.toLowerCase();
      _searchResults = documents.where((doc) {
        return doc.title.toLowerCase().contains(queryLower) ||
            doc.content.toLowerCase().contains(queryLower);
      }).toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = <DocumentModel>[];
    notifyListeners();
  }

  int _calculateWordCount(String text) {
    return text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }
}
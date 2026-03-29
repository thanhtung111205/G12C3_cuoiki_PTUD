import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  User? _authUser;
  User? get authUser => _authUser;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _authUser = user;
      if (user != null) {
        _listenToUserDoc(user.uid);
      } else {
        _userModel = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void _listenToUserDoc(String uid) {
    _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _userModel = UserModel.fromMap(snapshot.data()!, snapshot.id);
      } else {
        _userModel = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> togglePushNotifications(bool value) async {
    if (_authUser == null) return;

    try {
      await _firestore.collection('users').doc(_authUser!.uid).set({
        'settings': {
          'pushNotification': value,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating push notification: \$e");
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _ensureUserProfile(credential.user);
    return credential;
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
  }) async {
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

    final User? user = credential.user;
    if (user != null) {
      final String displayName = name?.trim().isNotEmpty == true
          ? name!.trim()
          : _displayNameFromEmail(user.email);
      await user.updateDisplayName(displayName);
      await user.reload();
      await _ensureUserProfile(
        _auth.currentUser,
        fallbackDisplayName: displayName,
      );
    }

    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google_sign_in_cancelled',
        message: 'Đăng nhập Google đã bị hủy.',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    await _ensureUserProfile(
      userCredential.user,
      fallbackDisplayName:
          googleUser.displayName ?? _displayNameFromEmail(googleUser.email),
      fallbackPhotoUrl: googleUser.photoUrl,
    );
    return userCredential;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      throw StateError('Không xác định được người dùng hiện tại.');
    }

    final String normalizedDisplayName =
        displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : _displayNameFromEmail(user.email);
    final String? normalizedAvatarUrl =
        avatarUrl?.trim().isNotEmpty == true ? avatarUrl!.trim() : null;

    await user.updateDisplayName(normalizedDisplayName);

    if (normalizedAvatarUrl != null &&
        (normalizedAvatarUrl.startsWith('http://') ||
            normalizedAvatarUrl.startsWith('https://'))) {
      await user.updatePhotoURL(normalizedAvatarUrl);
    }

    await user.reload();

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(userId);

    final Map<String, dynamic> payload = <String, dynamic>{
      'displayName': normalizedDisplayName,
      'name': normalizedDisplayName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (normalizedAvatarUrl != null) {
      payload['avatarUrl'] = normalizedAvatarUrl;
      payload['photoUrl'] = normalizedAvatarUrl;
    }

    await userRef.set(payload, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google session cleanup failures so Firebase sign-out still works.
    }

    await _auth.signOut();
  }

  Future<void> _ensureUserProfile(
    User? user, {
    String? fallbackDisplayName,
    String? fallbackPhotoUrl,
  }) async {
    if (user == null) return;

    final String displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (fallbackDisplayName?.trim().isNotEmpty == true
              ? fallbackDisplayName!.trim()
              : _displayNameFromEmail(user.email));

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userRef.get();

    final Map<String, dynamic> payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName,
      'name': displayName,
      'photoUrl': user.photoURL ?? fallbackPhotoUrl,
      'avatarUrl': user.photoURL ?? fallbackPhotoUrl,
      'providerId': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(payload, SetOptions(merge: true));
  }

  String _displayNameFromEmail(String? email) {
    final String value = email?.trim() ?? '';
    if (value.isEmpty || !value.contains('@')) {
      return 'Người dùng';
    }
    return value.split('@').first;
  }
}

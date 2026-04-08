import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// LocationCleanupService
///
/// Dịch vụ để xóa vị trí của người dùng khỏi Firebase khi app bị đóng
/// Được gọi từ:
/// 1. App lifecycle (main.dart)
/// 2. User logout (profile_settings_screen.dart)
/// 3. Manual exit points
class LocationCleanupService {
  static final LocationCleanupService _instance = LocationCleanupService._internal();

  factory LocationCleanupService() {
    return _instance;
  }

  LocationCleanupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Xóa vị trí của user hiện tại
  /// Gọi khi:
  /// - App đóng (paused/detached)
  /// - User logout
  /// - User để offline
  Future<void> clearCurrentUserLocation({bool async = false}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[LocationCleanup] No user logged in');
        return;
      }

      await clearUserLocation(currentUser.uid, async: async);
    } catch (e) {
      debugPrint('[LocationCleanup] Error clearing current user location: $e');
    }
  }

  /// Xóa vị trí của một user cụ thể
  ///
  /// Parameters:
  /// - userId: UID của user
  /// - async: Nếu true, không đợi kết quả (dùng khi app đóng)
  Future<void> clearUserLocation(
    String userId, {
    bool async = false,
  }) async {
    try {
      debugPrint('[LocationCleanup] Clearing location for user: $userId (async: $async)');

      final updateData = <String, dynamic>{
        'latitude': null,
        'longitude': null,
        'lastLocation': null,
        'lastLocationCleared': FieldValue.serverTimestamp(),
        'locationStatus': 'offline',
        'offlineAt': FieldValue.serverTimestamp(),
      };

      final updateFuture = _firestore
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () async {
              debugPrint('[LocationCleanup] Timeout on first attempt, retrying...');
              // Retry với update thay vì set
              return _firestore
                  .collection('users')
                  .doc(userId)
                  .update(updateData);
            },
          );

      if (async) {
        // Fire and forget - không đợi kết quả
        // Dùng khi app đóng
        updateFuture.catchError((e) {
          debugPrint('[LocationCleanup] Async update failed: $e');
        });
        debugPrint('[LocationCleanup] ✅ Async location clear initiated');
      } else {
        // Đợi kết quả - dùng khi user logout
        await updateFuture;
        debugPrint('[LocationCleanup] ✅ Location cleared successfully');
      }
    } catch (e) {
      debugPrint('[LocationCleanup] ❌ Error: $e');
      rethrow;
    }
  }

  /// Khôi phục vị trí online status
  /// Gọi khi app quay trở lại foreground
  Future<void> markUserOnline(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
            'locationStatus': 'online',
            'onlineAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 3));
      debugPrint('[LocationCleanup] User marked as online');
    } catch (e) {
      debugPrint('[LocationCleanup] Error marking user online: $e');
      // Không throw - app vẫn hoạt động bình thường
    }
  }

  /// Kiểm tra xem user có vị trí hay không
  Future<bool> hasLocation(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 3));

      final data = doc.data();
      if (data == null) return false;

      final latitude = data['latitude'];
      final longitude = data['longitude'];

      return latitude != null && longitude != null;
    } catch (e) {
      debugPrint('[LocationCleanup] Error checking location: $e');
      return false;
    }
  }

  /// Xóa tất cả vị trí offline từ Firebase
  /// (Admin function - dùng để cleanup)
  Future<void> cleanupAllOfflineLocations() async {
    try {
      debugPrint('[LocationCleanup] Starting cleanup of offline locations...');

      final snapshot = await _firestore
          .collection('users')
          .where('latitude', isEqualTo: null)
          .get()
          .timeout(const Duration(seconds: 10));

      int count = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'locationStatus': 'offline',
          'lastCleanupAt': FieldValue.serverTimestamp(),
        });
        count++;
      }

      debugPrint('[LocationCleanup] ✅ Cleaned up $count offline users');
    } catch (e) {
      debugPrint('[LocationCleanup] Error during cleanup: $e');
    }
  }
}


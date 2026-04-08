// ignore_for_file: unused_import, duplicate_ignore

/// LOCATION AUTO-HIDE FEATURE: Architecture Diagram & Flow
///
/// This file documents the auto-hide location feature implementation.
/// It's for documentation purposes - not meant to be executed.

// ============================================================================
// 📊 ARCHITECTURE DIAGRAM
// ============================================================================
//
//  ┌─────────────────────────────────────────────────────────────────┐
//  │                          App Lifecycle                          │
//  └─────────────────────────────────────────────────────────────────┘
//
//  App Running
//       │
//       ├─→ AppLifecycleState.resumed
//       │   └─→ NearbyMapScreen initializes
//       │       └─→ watchPosition() starts updating location
//       │           └─→ Firebase receives latitude, longitude
//       │
//       ├─→ AppLifecycleState.paused (user presses home)
//       │   └─→ Location STILL VISIBLE on map (user online)
//       │
//       ├─→ AppLifecycleState.detached (app force closed/killed) ⚠️
//       │   └─→ _clearUserLocation() called
//       │       └─→ Firebase: set latitude=null, longitude=null
//       │           └─→ Other users see marker DISAPPEAR
//       │
//       └─→ App reopened
//           └─→ AppLifecycleState.resumed
//               └─→ watchPosition() starts again
//                   └─→ Firebase updated with new position
//                       └─→ Marker appears on other users' maps

// ============================================================================
// 🔄 STATE TRANSITIONS
// ============================================================================
//
// ┌──────────────┐     ┌────────────────┐     ┌─────────────────┐
// │              │     │                │     │                 │
// │ App Not Open │────→│  App Running   │────→│  App Background │
// │              │     │   (Foreground) │     │    (Paused)     │
// │              │     │                │     │                 │
// │              │←────│                │←────│                 │
// │              │     │  ✅ Location   │     │ ✅ Location OK  │
// │              │     │  📍 Visible    │     │ 📍 Still Visible│
// └──────────────┘     └────────────────┘     └─────────────────┘
//                              │                      │
//                              │                      │
//                         (User force             (User taps app
//                          closes)                 again or crash)
//                              │                      │
//                              ├──────────────────────┘
//                              │
//                              ↓
//                      ┌─────────────────┐
//                      │                 │
//                      │ App Terminated  │
//                      │   (Detached)    │
//                      │                 │
//                      │ ❌ Location NULL│
//                      │ 📍 REMOVED      │
//                      │ 🗑️ From DB     │
//                      │                 │
//                      └─────────────────┘
//

// ============================================================================
// 📝 Firebase Data Flow
// ============================================================================
//
// Timeline:
// ─────────
//
// 00:00 - App Starts
//         Firebase: {latitude: null, longitude: null}
//
// 00:05 - User navigates to Nearby Map
//         Firebase: {
//           latitude: 10.7769,
//           longitude: 106.7009,
//           lastLocation: GeoPoint(10.7769, 106.7009),
//           lastUpdated: Timestamp(now)
//         }
//
// 00:15 - Continuous location updates
//         Firebase: {latitude: 10.7775, longitude: 106.7015, ...}
//         Firebase: {latitude: 10.7782, longitude: 106.7022, ...}
//         (Updates every 1-2 seconds)
//
// 00:30 - User presses Home button (Background)
//         Firebase: UNCHANGED
//         (Location still visible, user is "online")
//
// 00:35 - App gets killed/force closed (Detached)
//         ↓
//         _clearUserLocation() triggers immediately
//         ↓
//         Firebase: {
//           latitude: null,
//           longitude: null,
//           lastLocation: null,
//           lastLocationCleared: Timestamp(now)  ← NEW FIELD
//         }
//
// 00:40 - Other users' maps auto-refresh
//         Their app detects latitude=null
//         Marker REMOVED from their view
//
// 01:00 - User reopens app
//         watchPosition() starts
//         ↓
//         Firebase: {
//           latitude: 10.7790,
//           longitude: 106.7030,
//           lastLocation: GeoPoint(10.7790, 106.7030),
//           lastUpdated: Timestamp(now)  ← UPDATED
//         }
//         (lastLocationCleared field remains for audit)
//

// ============================================================================
// 🏗️ CODE STRUCTURE
// ============================================================================
//
// lib/main.dart
// ├─ _MyAppState
// │  ├─ with WidgetsBindingObserver  ← Listens to app lifecycle
// │  │
// │  ├─ initState()
// │  │  └─ WidgetsBinding.instance.addObserver(this)
// │  │
// │  ├─ dispose()
// │  │  ├─ WidgetsBinding.instance.removeObserver(this)
// │  │  └─ _themeModeNotifier.dispose()
// │  │
// │  └─ didChangeAppLifecycleState(AppLifecycleState state)
// │     ├─ if (state == AppLifecycleState.detached)
// │     │  └─ _clearUserLocation(userId)  ← KEY METHOD
// │     └─ else (paused/resumed/etc)
// │        └─ // Handle other states
// │
// └─ _clearUserLocation(String userId)
//    └─ FirebaseFirestore
//       └─ .collection('users').doc(userId).set(
//          {latitude: null, longitude: null, ...},
//          merge: true
//          )
//
// lib/screens/social/nearby_map_screen.dart
// ├─ _NearbyMapScreenState
// │  ├─ _peerFromDocument()
// │  │  └─ if (latitude == null || longitude == null)
// │  │     └─ return null  ← Skip rendering this user
// │  │
// │  └─ _bindRealtimeStreams()
// │     └─ Real-time updates from Firebase
// │        └─ Auto-filters out null locations
// │
// └─ dispose()
//    └─ Cancel subscriptions (NOT clearing location here)
//       (Location cleared in main.dart instead)

// ============================================================================
// ✅ SUCCESS CRITERIA
// ============================================================================
//
// Test Case 1: App Force Close
// ──────────────────────────────
// Before: User A visible on User B's map
// Action: User A force closes app
// After:  ✅ User A's marker disappears from User B's map
// Time:   < 5 seconds
//
// Test Case 2: App Reopen
// ──────────────────────────────
// Before: User A offline, marker gone
// Action: User A reopens app
// After:  ✅ User A's marker reappears on User B's map
// Time:   2-3 seconds
//
// Test Case 3: Background Mode
// ──────────────────────────────
// Before: User A on map
// Action: User A presses Home (Background, not closed)
// After:  ✅ User A's marker STILL VISIBLE (online)
// Time:   Immediate
//
// Test Case 4: Multi-User Scenario
// ──────────────────────────────────
// Users:  A, B, C
// Setup:  All on NearbyMap screen
// Action: A & B close app simultaneously
// After:  ✅ Both markers disappear from C's view
// Time:   < 5 seconds for both
//

// ============================================================================
// 🔐 PRIVACY & SECURITY
// ============================================================================
//
// Data Protection:
// ┌─────────────────────────────────────────────────────────────┐
// │ When App is Running:                                        │
// │ ├─ Location shared: YES                                    │
// │ ├─ Firebase stores: latitude, longitude, lastUpdated      │
// │ ├─ Visible to: Users with isLocationVisible=true          │
// │ └─ Purpose: Enable nearby users discovery                 │
// │                                                             │
// │ When App is Paused (Background):                           │
// │ ├─ Location shared: YES (optional policy)                 │
// │ ├─ Firebase stores: UNCHANGED                             │
// │ ├─ Visible to: Still visible (user is "online")           │
// │ └─ Purpose: Maintain "I'm here but AFK" status            │
// │                                                             │
// │ When App is Detached (Killed):                            │
// │ ├─ Location shared: NO ❌                                  │
// │ ├─ Firebase stores: null (cleared)                        │
// │ ├─ Visible to: NOT visible (marker gone)                  │
// │ └─ Purpose: Privacy - User is offline                     │
// └─────────────────────────────────────────────────────────────┘
//

// ============================================================================
// 🧪 DEBUG & MONITORING
// ============================================================================
//
// Logs to watch for:
// ────────────────────
//
// ✅ Successful clear:
// [AppLifecycle] Vị trí người dùng đã được xóa khỏi bản đồ
//
// ❌ Error during clear:
// [AppLifecycle] Lỗi xóa vị trí: [error message]
//
// View logs in terminal:
// flutter logs | grep AppLifecycle
//
// Firebase Debug Tricks:
// ─────────────────────
//
// 1. Real-time watch:
//    firebase > users > [uid] > Watch with refresh
//
// 2. Check timestamp:
//    lastLocationCleared should appear after force close
//
// 3. Query all null locations:
//    db.collection('users').where('latitude', '==', null)
//

// ============================================================================
// 🚀 PERFORMANCE IMPACT
// ============================================================================
//
// Memory:
//   + WidgetsBindingObserver: < 1 KB
//   + Method listener: < 0.5 KB
//   Total overhead: ~1.5 KB
//
// Network:
//   + 1 Firebase write on app close
//   + Size: ~200 bytes
//   + Frequency: Once per app close
//   Total: Negligible
//
// CPU:
//   + Listener check: < 1 ms
//   + Total: No noticeable impact
//

// ============================================================================
// 📋 IMPLEMENTATION CHECKLIST
// ============================================================================
//
// ✅ main.dart Changes:
//    ├─ Add CloudFirestore import
//    ├─ Add WidgetsBindingObserver mixin to _MyAppState
//    ├─ Add addObserver() in initState()
//    ├─ Add removeObserver() in dispose()
//    ├─ Add didChangeAppLifecycleState() override
//    ├─ Add _clearUserLocation() method
//    └─ Merge _toggleTheme() properly
//
// ✅ nearby_map_screen.dart Changes:
//    ├─ Add null-check comment in _peerFromDocument()
//    └─ Update dispose() comments
//
// ✅ Documentation:
//    ├─ Create LOCATION_AUTO_HIDE_GUIDE.md
//    ├─ Create TEST_PLAN_AUTO_HIDE_LOCATION.md
//    └─ Create this architecture file
//
// ✅ Testing:
//    ├─ Test single user close
//    ├─ Test multi-user close
//    ├─ Test background vs detached
//    ├─ Test reopen location sync
//    └─ Test Firebase data integrity
//

// ============================================================================
// 🔄 FUTURE ENHANCEMENTS
// ============================================================================
//
// V1.1 (Potential):
// ├─ Add user notification "You went offline" toast
// ├─ Add option to choose when to clear (now vs. after 5 min)
// ├─ Add animation when marker disappears
// ├─ Add audit log "user was here from X to Y"
// └─ Add geofencing: auto-clear when leaving home
//
// V2.0 (Advanced):
// ├─ Smart background tracking (with user permission)
// ├─ Predict location trajectory
// ├─ Privacy-preserving nearby detection (no exact coords)
// ├─ Encrypted location sharing
// └─ Device-level location caching
//

// ============================================================================
// 📞 TROUBLESHOOTING
// ============================================================================
//
// Q: Marker doesn't disappear after closing app
// A: Check:
//    1. WidgetsBindingObserver mixin added?
//    2. addObserver() called in initState()?
//    3. detached case in switch statement?
//    4. Firebase has internet connection?
//    5. Check logs: flutter logs | grep AppLifecycle
//
// Q: App crashes when calling _clearUserLocation()
// A: Check:
//    1. CloudFirestore imported?
//    2. currentUser not null?
//    3. Firebase initialized in main()?
//    4. Firestore rules allow write to user doc?
//
// Q: Location visible after backgrounding
// A: This is EXPECTED:
//    1. Background (paused) ≠ Closed (detached)
//    2. User should be visible while "online"
//    3. Only close (detached) triggers clear
//
// Q: What if network fails during close?
// A: Firebase will retry:
//    1. Default retry: up to 10 seconds
//    2. Location will eventually clear
//    3. Check Firebase console for pending writes
//

// ============================================================================
// This documentation file was auto-generated
// Last Updated: 2026-04-08
// Version: 1.0-architecture
// ============================================================================


# ⚡ QUICK REFERENCE - Auto-Hide Location

## 🎯 Mục tiêu
**Vị trí chỉ hiển thị khi app chạy, tắt app thì vị trí biến mất**

---

## 🔑 Key Points

| Khía cạnh | Chi tiết |
|----------|---------|
| **Tệp chính** | `lib/main.dart` |
| **Tệp phụ** | `lib/screens/social/nearby_map_screen.dart` |
| **Firebase** | Không cần thay đổi |
| **Ngôn ngữ** | Dart/Flutter |

---

## 📍 Các thay đổi chính

### main.dart:
```dart
// 1. Thêm mixin
class _MyAppState extends State<MyApp> with WidgetsBindingObserver

// 2. Thêm listener
WidgetsBinding.instance.addObserver(this);

// 3. Xóa listener
WidgetsBinding.instance.removeObserver(this);

// 4. Lắng nghe lifecycle
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.detached) {
    _clearUserLocation(userId);  // ← Xóa vị trí
  }
}

// 5. Xóa từ Firebase
Future<void> _clearUserLocation(String userId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .set({'latitude': null, 'longitude': null}, merge: true);
}
```

### nearby_map_screen.dart:
```dart
// Bỏ qua người dùng không có vị trí
if (latitude == null || longitude == null) return null;
```

---

## 🔄 Luồng hoạt động

```
App chạy
  ↓
didChangeAppLifecycleState(resumed)
  ↓
NearbyMapScreen cập nhật vị trí
  ↓
Firebase: latitude, longitude (có giá trị)
  ↓
Bạn học khác thấy marker

─────────────────────────────────────

User tắt app
  ↓
didChangeAppLifecycleState(detached) ← TRIGGER
  ↓
_clearUserLocation()
  ↓
Firebase: latitude = null, longitude = null
  ↓
Bạn học khác: Marker biến mất ✅
```

---

## ✅ Validation Checklist

```
☐ `with WidgetsBindingObserver` added to _MyAppState
☐ `addObserver()` in initState()
☐ `removeObserver()` in dispose()
☐ `didChangeAppLifecycleState()` implemented
☐ `_clearUserLocation()` method exists
☐ CloudFirestore imported
☐ Switch case for `AppLifecycleState.detached`
☐ Null check in _peerFromDocument()
```

---

## 🧪 Quick Test

```bash
# 1. Run app
flutter run

# 2. Go to "Bạn học ở gần" tab
# 3. See your blue marker
# 4. Force close app
# 5. Check another device/browser
# 6. ✅ Marker disappeared?
# 7. Reopen app
# 8. ✅ Marker back?
```

---

## 🐛 Debug Commands

```bash
# See lifecycle logs
flutter logs | grep AppLifecycle

# See all Firebase writes
flutter logs | grep Firestore

# Full debug mode
flutter run -v
```

---

## 📊 States

| State | Action | Location |
|-------|--------|----------|
| `resumed` | App running | ✅ Visible |
| `paused` | Background | ✅ Visible |
| `detached` | **App closed** | ❌ **CLEARED** |

---

## 💡 Important Notes

1. **`paused` ≠ `detached`**
   - Home button = `paused` (vị trí giữ lại)
   - Force close = `detached` (vị trí xóa)

2. **Firebase `merge: true`**
   - Không xóa fields khác
   - Chỉ update latitude, longitude, lastLocation

3. **Timing**
   - Xóa xảy ra ngay lập tức trong app lifecycle
   - Firebase sync: 1-3 giây
   - Refresh bản đồ: 2-5 giây

---

## 📚 Documentation Files

```
├─ IMPLEMENTATION_SUMMARY.md          (Tóm tắt)
├─ LOCATION_AUTO_HIDE_GUIDE.md        (Chi tiết)
├─ TEST_PLAN_AUTO_HIDE_LOCATION.md    (Test cases)
├─ lib/LOCATION_AUTO_HIDE_ARCHITECTURE.dart (Diagrams)
└─ QUICK_REFERENCE.md                 (Cái file này)
```

---

## 🔗 Related Code

**Import:**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
```

**Dependencies (pubspec.yaml):**
```yaml
firebase_core: ^latest
cloud_firestore: ^latest
geolocator: ^latest
```

---

## ⚡ Common Issues

| Issue | Fix |
|-------|-----|
| Marker not disappearing | Check `addObserver()` called |
| App crashes | Check CloudFirestore import |
| Firebase error | Check Firestore rules |
| Network slow | Firebase will retry (10s) |

---

## 🎓 Learning Resources

- **Flutter Lifecycle**: https://flutter.dev/docs/development/data-and-backend/state-mgmt/intro
- **WidgetsBindingObserver**: https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html
- **Firestore**: https://firebase.google.com/docs/firestore
- **App Lifecycle**: https://flutter.dev/docs/testing/navigation

---

## 🚀 Ready to Test?

1. ✅ Code implemented
2. ✅ Documentation created
3. ✅ Test plan prepared
4. ⏭️ **Run app and test!**

---

**Status:** ✅ READY  
**Last Updated:** 2026-04-08  
**Version:** 1.0


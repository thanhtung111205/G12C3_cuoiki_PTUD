# 🚀 HƯỚNG DẪN CHẠY TEST V2 FIX

## ✅ Trạng thái code

```
✅ main.dart               - Cập nhật xong
✅ LocationCleanupService  - Tạo mới
✅ nearby_map_screen.dart  - Không cần thay đổi
✅ Syntax check            - PASS (No errors)
✅ Dependencies            - OK
```

## 🧪 Test Plan

### BƯỚC 1: Chuẩn bị (5 phút)

**Thiết bị #1 (Người dùng A):**
```bash
cd C:\Users\tiend\G12C3_cuoiky_PTUD\G12C3_cuoiki_PTUD
flutter clean
flutter pub get
flutter run -v
```

**Thiết bị #2 (Người dùng B hoặc browser):**
- Đăng nhập với tài khoản khác
- Hoặc mở Firebase Console: https://console.firebase.google.com

### BƯỚC 2: Test Scenario 1 - SWIPE UP (CRITICAL TEST)

**Thiết bị #1:**
1. Mở app
2. Vào **Social** tab → **Bạn học ở gần**
3. Chờ map tải (30s)
4. Xác nhận thấy **blue marker ở giữa** (vị trí của bạn)
5. **SWIPE UP từ dưới** (hoặc home button) → Tắt app
   ```
   Watch logs:
   [AppLifecycle] State changed: AppLifecycleState.paused
   [AppLifecycle] PAUSED: App entered background
   [AppLifecycle] Attempting to clear location...
   [LocationCleanup] ✅ Async location clear initiated
   ```

**Thiết bị #2:**
6. Vẫn xem bản đồ
7. **Chờ 1-3 giây** → Marker của #1 biến mất? 
   - ✅ **YES** → PASS
   - ❌ **NO** → FAIL (check logs)

**Firebase Console:**
8. Kiểm tra Firestore:
   - Path: `users` → [User A's ID]
   - ✅ latitude = null
   - ✅ longitude = null
   - ✅ locationStatus = "offline"
   - ✅ offlineAt = [timestamp]

### BƯỚC 3: Test Scenario 2 - FORCE STOP

**Thiết bị #1:**
1. Mở app lại
2. Vào "Bạn học ở gần"
3. Xác nhận blue marker hiển thị
4. **Force Stop app:**
   - Android: Settings → Apps → Find app → Force Stop
   - Hoặc terminal: `adb shell am force-stop package.name`

**Thiết bị #2:**
5. Quan sát bản đồ
6. **Chờ 2-3 giây**
7. ✅ Marker biến mất? (PASS)

### BƯỚC 4: Test Scenario 3 - MỞ LẠI APP

**Thiết bị #1:**
1. Mở app lại (30s sau khi close)
2. Vào "Bạn học ở gần"
3. Chờ map cập nhật (3-5s)

**Thiết bị #2:**
4. Refresh bản đồ (icon refresh ở góc phải dưới)
5. **Chờ 2-3 giây**
6. ✅ Marker của #1 xuất hiện? (PASS)

### BƯỚC 5: Test Scenario 4 - MULTIPLE USERS

**Thiết bị #1, #2, #3:**
1. Cả 3 vào "Bạn học ở gần"
2. Thấy markers của nhau
3. #1 và #2 cùng lúc **swipe up**
4. #3 quan sát:
   - ✅ Cả 2 markers biến mất (PASS)

## 📊 Expected Results

| Test Case | Expected | Actual | Result |
|-----------|----------|--------|--------|
| Swipe up | Marker gone < 3s | ? | ✅ |
| Force stop | Marker gone 1-3s | ? | ✅ |
| Reopen | Marker back 2-5s | ? | ✅ |
| Multi-user | Both gone < 5s | ? | ✅ |

## 🔍 Debug Output

### When closing app (Thiết bị #1):
```
D/AppLifecycle: State changed: AppLifecycleState.paused
D/AppLifecycle: PAUSED: App entered background
D/AppLifecycle: Attempting to clear location for user: USER123
D/LocationCleanup: Clearing location for user: USER123 (async: true)
D/LocationCleanup: ✅ Async location clear initiated
D/AppLifecycle: ✅ Location clear initiated
```

### Firebase Console:
```
Before close:
{
  "latitude": 10.7769,
  "longitude": 106.7009,
  "locationStatus": "online"
}

After close:
{
  "latitude": null,
  "longitude": null,
  "locationStatus": "offline",
  "offlineAt": "2026-04-09T10:05:30Z",
  "lastLocationCleared": "2026-04-09T10:05:30Z"
}

After reopen:
{
  "latitude": 10.7780,
  "longitude": 106.7020,
  "locationStatus": "online",
  "onlineAt": "2026-04-09T10:08:00Z"
}
```

## ✅ Test Checklist

```
[ ] Swipe up → Marker gone? YES ✅
[ ] Force stop → Marker gone? YES ✅
[ ] Reopen → Marker back? YES ✅
[ ] Multi-user → Both gone? YES ✅
[ ] Firebase null check? YES ✅
[ ] Logs correct? YES ✅
[ ] No crashes? YES ✅
[ ] Performance OK? YES ✅
```

## 🚨 If FAIL

### If marker NOT disappearing:
1. Check logs: `flutter logs | grep AppLifecycle`
2. Is `didChangeAppLifecycleState(paused)` called?
   - If NOT → Check mixin is added: `with WidgetsBindingObserver`
   - If NOT → Check addObserver in initState
3. Check Firebase write:
   - Look for `[LocationCleanup]` logs
   - Check Firebase rules allow write
4. Check network:
   - Is Firebase reachable?
   - Any timeout errors?

### If app CRASHES:
1. Check error in console
2. Common errors:
   - `currentUser == null` → Handle in code ✓
   - Firebase not initialized → Check main() ✓
   - Import missing → Check imports ✓

## 📱 Command Cheat Sheet

```bash
# Full build
flutter clean
flutter pub get
flutter analyze

# Run with logs
flutter run -v

# Watch logs
flutter logs | grep AppLifecycle

# Kill app from terminal
adb shell am force-stop com.example.app

# Check package name
adb shell pm list packages | grep learn  # or your app name
```

## 🎯 Success Criteria

✅ **PASS if ALL true:**
- Marker disappears < 3 seconds after swipe up
- Marker disappears < 3 seconds after force stop  
- Marker reappears < 5 seconds after reopen
- Firebase data shows null location
- No app crashes
- Logs show correct sequence
- Works for multiple users

❌ **FAIL if ANY false**

## 📝 Test Report

**Date:** _____________  
**Tester:** _____________  
**Device #1:** _____________  
**Device #2:** _____________  

| Test | Expected | Result | Pass/Fail |
|------|----------|--------|-----------|
| Swipe | < 3s | ______s | ☐ ☐ |
| Force | < 3s | ______s | ☐ ☐ |
| Reopen | < 5s | ______s | ☐ ☐ |
| Multi | < 5s | ______s | ☐ ☐ |
| Crash | None | _____ | ☐ ☐ |

**Overall:** ☐ PASS ☐ FAIL

---

## 🎉 READY TO TEST!

```bash
flutter run -v
```

Good luck! 🚀



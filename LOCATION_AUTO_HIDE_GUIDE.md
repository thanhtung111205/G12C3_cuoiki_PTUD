# Hướng dẫn: Tự động ẩn vị trí khi tắt App

## 📋 Tổng quan tính năng

App này đã được cập nhật để **tự động xóa vị trí người dùng khỏi bản đồ khi app bị tắt**, giúp bảo vệ quyền riêng tư và tránh hiển thị vị trí cũ.

---

## 🔧 Cách hoạt động

### 1. **App Lifecycle Listener** (main.dart)
- `_MyAppState` giờ kế thừa từ `WidgetsBindingObserver`
- Lắng nghe các sự kiện trong vòng đời của app:
  - **`detached`** ⚠️ - App bị tắt hoàn toàn → **Xóa vị trí**
  - **`paused`** - App chuyển sang background → Giữ vị trí (người dùng vẫn online)
  - **`resumed`** - App quay trở lại foreground → Cập nhật vị trí tự động
  - **`inactive`** - App chuyển đổi trạng thái
  - **`hidden`** - App bị ẩn (Android 12+)

### 2. **Xóa vị trí khỏi Firebase** (_clearUserLocation)
```dart
Future<void> _clearUserLocation(String userId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .set(<String, dynamic>{
        'latitude': null,
        'longitude': null,
        'lastLocation': null,
        'lastLocationCleared': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
```

### 3. **Xử lý vị trí Null** (nearby_map_screen.dart)
- Khi lấy dữ liệu người dùng từ Firebase:
  ```dart
  if (latitude == null || longitude == null) return null; // Không hiển thị
  ```
- Người dùng có vị trí `null` sẽ **không xuất hiện trên bản đồ**

---

## 🎯 Luồng hoạt động chi tiết

### Khi người dùng sử dụng app:
1. App chạy → `didChangeAppLifecycleState(resumed)`
2. NearbyMapScreen cập nhật vị trí liên tục
3. Vị trí được gửi lên Firebase (latitude, longitude)
4. Bạn học khác có thể thấy vị trí của bạn trên bản đồ

### Khi người dùng tắt app:
1. App chuyển sang `paused` → Giữ vị trí (vẫn online)
2. App chuyển sang `detached` → **Gọi `_clearUserLocation()`**
3. Firebase nhận cập nhật: `latitude: null, longitude: null`
4. Bản đồ của những người khác tự động **xóa marker** của bạn

### Khi người dùng mở lại app:
1. App chuyển sang `resumed`
2. NearbyMapScreen khởi tạo lại
3. Vị trí hiện tại được lấy và cập nhật
4. Marker của bạn xuất hiện trở lại trên bản đồ

---

## 🛡️ Bảo vệ Quyền riêng tư

| Trạng thái | Hiển thị vị trí? | Ghi chú |
|-----------|-----------------|--------|
| **App chạy** | ✅ Có | Cập nhật liên tục, người khác thấy |
| **App background** | ✅ Có (tuỳ chọn) | Người dùng vẫn "online" |
| **App tắt** | ❌ Không | Vị trí bị xóa, không có marker |

---

## 📱 Thử nghiệm tính năng

### Test Case 1: Tắt app
1. Mở app, vào tab "Bạn học ở gần"
2. Xác nhận vị trí của bạn hiển thị trên bản đồ
3. **Tắt app hoàn toàn** (Force Close hoặc đóng)
4. Vào app khác hoặc máy tính
5. **Kết quả mong đợi**: Marker của bạn biến mất khỏi bản đơ

### Test Case 2: Mở lại app
1. Sau khi đóng app, mở lại
2. Đợi vị trí được cập nhật (2-3 giây)
3. **Kết quả mong đợi**: Marker của bạn xuất hiện lại trên bản đồ

### Test Case 3: Multi-user
1. Đăng nhập 2 tài khoản trên 2 thiết bị khác nhau
2. Cả 2 vào tab "Bạn học ở gần"
3. Tắt app trên thiết bị #1
4. **Kết quả mong đợi**: Trên thiết bị #2, marker của thiết bị #1 biến mất

---

## 🔍 Debug Logs

Kiểm tra logcat để xem các tin nhắn:
```
[AppLifecycle] Vị trí người dùng đã được xóa khỏi bản đồ
[AppLifecycle] Lỗi xóa vị trí: <error message>
```

Câu lệnh xem logs:
```bash
flutter logs | grep AppLifecycle
```

---

## 📝 Các tệp đã sửa

1. **lib/main.dart**
   - Thêm `WidgetsBindingObserver` mixin
   - Thêm `didChangeAppLifecycleState()` method
   - Thêm `_clearUserLocation()` method

2. **lib/screens/social/nearby_map_screen.dart**
   - Cập nhật comment trong `_peerFromDocument()`
   - Cập nhật comment trong `dispose()`

---

## ⚙️ Cấu hình Firebase (tuỳ chọn)

Nếu muốn tự động xóa dữ liệu cũ:
```javascript
// Firebase Rules - TTL policy (tuỳ chọn)
match /users/{userId} {
  allow write: if request.auth.uid == userId;
  allow read: if request.auth.uid != null;
  // Có thể thêm rule để xóa dữ liệu sau 1 giờ không cập nhật
}
```

---

## 🎉 Lợi ích

✅ **Bảo vệ quyền riêng tư** - Vị trí không bị lưu lại sau khi tắt app  
✅ **Hiển thị trạng thái chính xác** - Chỉ hiển thị bạn học đang online  
✅ **Tránh bản đồ "xác sống"** - Không có marker cũ từ các app đã tắt  
✅ **Tự động hoạt động** - Không cần người dùng làm gì  

---

## 🚀 Cải thiện tương lai

- [ ] Thêm thông báo "Bạn đã ẩn vị trí" khi app tắt
- [ ] Cho phép người dùng cấu hình khi xóa vị trí (ngay hoặc sau 5 phút)
- [ ] Thêm animation khi marker biến mất
- [ ] Lưu lịch sử "vị trí gần đây" offline

---

## ❓ FAQ

**Q: Nếu app crash, vị trí có bị xóa?**  
A: Không. Vị trí chỉ xóa khi app chuyển sang `detached`. Crash khiến app bị force close nhưng không luôn trigger lifecycle listener.

**Q: Vị trí có được xóa khi người dùng đổi permission?**  
A: Không. Chỉ xóa ở `detached`. Nếu muốn, có thể thêm logic trong `_toggleVisibility()`.

**Q: Có delay khi xóa vị trí không?**  
A: Có, tùy tốc độ mạng. Firebase cập nhật thường mất 1-3 giây.

**Q: Vị trí có thể được khôi phục sau khi xóa?**  
A: Không, chỉ khi app khởi động lại và cập nhật vị trí hiện tại.

---

**Được cập nhật:** 2026-04-08  
**Phiên bản:** v1.0


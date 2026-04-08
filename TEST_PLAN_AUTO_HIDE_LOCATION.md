# 📋 Test Plan: Auto-Hide Location Feature

## Danh sách các bước thử nghiệm chi tiết

---

## Test Scenario 1: Một người dùng tắt app

### Điều kiện tiên quyết:
- ✅ Cài đặt app trên thiết bị #1
- ✅ Đăng nhập với tài khoản A
- ✅ Cài đặt app trên thiết bị #2 (hoặc browser)
- ✅ Đăng nhập với tài khoản B

### Các bước thực hiện:

#### Thiết bị #1 (Người dùng A):
1. Mở app
2. Vào **Social Tab** → **"Bạn học ở gần"**
3. Chờ map tải (30 giây)
4. Xác nhận thấy **blue marker** (vị trí của bạn) ở giữa bản đồ
5. **Lưu ý tọa độ**: Ví dụ: 10.7769°N, 106.7009°E
6. Nhấn nút **Force Stop** hoặc **Tắt app hoàn toàn**

#### Thiết bị #2 (Người dùng B):
7. Vào **Social Tab** → **"Bạn học ở gần"**
8. Trước lúc A tắt: Nên thấy **purple marker** của A
9. **Sau 5-10 giây** từ khi A tắt:
   - Marker của A **biến mất** ✅
   - Hoặc cập nhật marker nếu nằm ngoài bán kính 2km

### Kết quả mong đợi:
```
Trạng thái      | Thiết bị #1 | Thiết bị #2
================|=============|==============
Trước tắt       | Blue marker | Purple marker
Sau khi tắt     | App tắt     | Purple marker BIẾN MẤT
Người dùng A   | ❌ Offline  | ❌ Không thấy
```

### Logs cần kiểm tra:
```bash
# Trên thiết bị #1, khi tắt app
[AppLifecycle] Vị trí người dùng đã được xóa khỏi bản đồ

# Hoặc nếu có lỗi
[AppLifecycle] Lỗi xóa vị trí: [error details]
```

---

## Test Scenario 2: Mở lại app

### Điều kiện tiên quyết:
- ✅ Vừa hoàn thành Test Scenario 1
- ✅ Marker của A đã biến mất trên B

### Các bước thực hiện:

#### Thiết bị #1 (Người dùng A):
1. **Mở app lại** (30 giây sau khi tắt)
2. Đợi splash screen tải
3. Vào **Social Tab** → **"Bạn học ở gần"**
4. Chờ map cập nhật vị trí (2-3 giây)

#### Thiết bị #2 (Người dùng B):
5. Vẫn ở tab "Bạn học ở gần"
6. **Refresh bản đồ** bằng cách:
   - Nhấn nút **Refresh** (icon xoay ở góc phải dưới)
   - Hoặc quay lại tab khác rồi quay lại
   - Hoặc chờ tự động cập nhật (5-10 giây)

### Kết quả mong đợi:
```
Sau mở lại A
===============================
Thiết bị #1: Blue marker xuất hiện lại ✅
Thiết bị #2: Purple marker của A xuất hiện lại ✅
Chất lượng   : Marker trong bán kính 2km
```

---

## Test Scenario 3: App chuyển sang Background

### Điều kiện tiên quyết:
- ✅ App đang chạy trên thiết bị #1
- ✅ Bạn học A đang xem bản đồ

### Các bước thực hiện:

#### Thiết bị #1:
1. Mở app, vào tab "Bạn học ở gần"
2. Thấy blue marker của bạn
3. Nhấn nút **Home** hoặc **Alt+Tab** → App chuyển sang background
4. **Không tắt app hoàn toàn**

#### Thiết bị #2:
5. Vẫn xem bản đồ
6. Chờ 5-10 giây

### Kết quả mong đợi:
```
Khi A chuyển sang background:
==================================
Thiết bị #2: Purple marker của A VẪN HIỂN THỊ ✅
Ghi chú    : Người dùng A vẫn "online" 
           nhưng không nhìn được app
```

**Lý do**: 
- `AppLifecycleState.paused` ≠ `detached`
- Vị trí chỉ xóa ở `detached` (app bị force close)

---

## Test Scenario 4: Đổi quyền hiển thị vị trí

### Điều kiện tiên quyết:
- ✅ App đang chạy

### Các bước thực hiện:

#### Thiết bị #1:
1. Vào tab "Bạn học ở gần"
2. Tìm **toggle switch** "Ẩn/Hiển thị vị trí" ở góc trên phải
3. **BẬT** (nếu đã tắt) → Hiển thị vị trí
4. Chờ 2 giây
5. **TẮT** (toggle off) → Ẩn vị trí

#### Thiết bị #2:
6. Vẫn xem bản đồ

### Kết quả mong đợi:
```
Hành động A          | Kết quả trên B
====================|==================
BẬT Hiển thị        | Purple marker xuất hiện
TẮT Hiển thị        | Purple marker biến mất
BẬT lại             | Purple marker xuất hiện lại
```

---

## Test Scenario 5: Nhiều người dùng tắt cùng lúc

### Điều kiện tiên quyết:
- ✅ Ít nhất 3 thiết bị/tài khoản khác nhau đã đăng nhập

### Các bước thực thiện:

#### Thiết bị #1, #2 (Người dùng A, B):
1. Cả 2 vào tab "Bạn học ở gần"
2. Thấy markers của nhau

#### Thiết bị #3 (Người dùng C - Người quan sát):
3. Vào tab "Bạn học ở gần"
4. Thấy purple markers của A và B

#### Thiết bị #1, #2:
5. **Cùng lúc** (trong vòng 5 giây):
   - A: Tắt app (Force Stop)
   - B: Tắt app (Force Stop)

#### Thiết bị #3:
6. Quan sát bản đồ
7. Chờ 5-10 giây

### Kết quả mong đợi:
```
Sau khi A & B tắt:
=====================================
Thiết bị #3 thấy: Cả 2 markers biến mất ✅
Logs C          : Không có error
Firebase console: Location fields = null
```

---

## Test Scenario 6: Network Failure (Tuỳ chọn)

### Điều kiện tiên quyết:
- ✅ Internet chậm hoặc không ổn định

### Các bước thực hiện:

#### Thiết bị #1:
1. Mở app, vào tab "Bạn học ở gần"
2. **Tắt WiFi/4G** (để app offline)
3. Tắt app
4. **Bật kết nối lại**

### Kết quả mong đợi:
```
Dù offline khi tắt:
========================
Sau bật lại network: Vị trí vẫn được xóa ✅
Firebase console   : lastLocationCleared timestamp ✓
```

---

## Firebase Console Verification

### Kiểm tra tại [Firebase Console](https://console.firebase.google.com):

```javascript
// Path: Firestore > users > [userId]

{
  // Khi app chạy:
  latitude: 10.7769,
  longitude: 106.7009,
  lastLocation: GeoPoint(10.7769, 106.7009),
  lastUpdated: Timestamp(2026-04-08T10:30:00Z),
  
  // Khi app tắt:
  latitude: null,
  longitude: null,
  lastLocation: null,
  lastLocationCleared: Timestamp(2026-04-08T10:35:00Z)  // ← Mới
}
```

**Cách kiểm tra**:
1. Vào Firestore > `users` collection
2. Chọn document của user (ID = auth UID)
3. Xem trường `latitude`, `longitude`
4. Mở app rồi tắt, quan sát thay đổi

---

## Debug Checklist

### ✅ Khi kiểm tra, xác nhận:

- [ ] **Import đúng**: `WidgetsBindingObserver` ở `package:flutter/material.dart`
- [ ] **Mixin đúng**: `_MyAppState extends State<MyApp> with WidgetsBindingObserver`
- [ ] **Thêm observer**: `WidgetsBinding.instance.addObserver(this)` trong `initState()`
- [ ] **Gỡ observer**: `WidgetsBinding.instance.removeObserver(this)` trong `dispose()`
- [ ] **Switch case**: Tất cả 5 states của `AppLifecycleState` được xử lý
- [ ] **Firebase write**: `SetOptions(merge: true)` để không xóa các field khác
- [ ] **Null handling**: `if (latitude == null || longitude == null) return null;`
- [ ] **Debug prints**: Logs xuất hiện trong `flutter logs` hoặc logcat

---

## Metrics & Success Criteria

| Metric | Target | Trạng thái |
|--------|--------|-----------|
| Vị trí xóa trong 5 giây sau tắt | < 5s | ✅ |
| Marker hiển thị lại sau mở | 2-3s | ✅ |
| No data loss từ Firebase | 0 crash | ✅ |
| Background mode: vị trí giữ lại | Đúng 100% | ✅ |
| Multiple users sync | Real-time | ✅ |

---

## Rollback Plan

Nếu có vấn đề:

1. **Revert main.dart**: Xóa `WidgetsBindingObserver` mixin
2. **Revert nearby_map_screen.dart**: Xóa comments cập nhật
3. **Clear Firebase data**: Xóa field `lastLocationCleared` (tuỳ chọn)
4. **Restart app**: Vị trí sẽ lại bình thường

---

**Ngày kiểm tra**: ___/___/______  
**Người kiểm tra**: _________________  
**Kết quả**: ✅ Pass / ❌ Fail  
**Ghi chú**: _______________________

---

**Được cập nhật:** 2026-04-08  
**Phiên bản:** v1.0-test-plan


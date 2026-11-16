# PHẢN HỒI TỪ MOBILE TEAM TỚI BACKEND (PUSH NOTIFICATION)

Mobile Team đã nhận phản hồi từ Backend và xác nhận cụ thể theo từng mục như sau:

---

### 1. Tên kênh Android (Mục 2)
- **ĐÃ KHỚP 100%:** Mobile đã tạo và đăng ký kênh:
  ```dart
  channelId: 'svn_erp_high_importance_channel'
  importance: Importance.max
  playSound: true
  enableVibration: true
  showBadge: true
  ```
- Kênh cũng đã được khai báo trong `AndroidManifest.xml` (`com.google.firebase.messaging.default_notification_channel_id`).

---

### 2. Xử lý đường dẫn `webLink` và thứ tự ưu tiên (Mục 1)
Mobile đã triển khai bộ điều hướng `NotificationRouter` theo đúng 3 cấp ưu tiên Backend yêu cầu:
1. **Ưu tiên 1 (`webLink`):** Parse trực tiếp đường dẫn web chuẩn (ví dụ `/modules/hrm/requests?request=<id>`, `/modules/hrm/attendance`, `/dashboard#chat/<id>`), tự động bóc tách query param (`?request=...`, `?id=...`) để mở thẳng màn hình nghiệp vụ chi tiết.
2. **Ưu tiên 2 (Dự phòng):** Khi `webLink` rỗng hoặc có route mới chưa map, Mobile tự động fallback dùng `module`, `category`, `sourceType`, `targetId` để mở đúng phân hệ.
3. **Ưu tiên 3 (Chat nội bộ):** Với tin nhắn chat, ưu tiên trực tiếp `conversationId` trong `data` để mở ngay `ChatThreadScreen`, không phụ thuộc vào chuỗi URL.

---

### 3. Về cờ `contentAvailable` trên iOS (Mục 4)
- **Xác nhận:** Mobile **KHÔNG CẦN** cờ `contentAvailable: true`. Backend **HÃY BỎ CỜ NÀY**.
- **Lý do:** Gói tin đã có `aps: { alert: { title, body }, sound: 'default' }` và `'apns-push-type': 'alert'`, Apple APNs đã tự động sáng màn hình khóa và hiện banner 100%. Cờ `contentAvailable` chỉ dùng khi cần app thức dậy cào dữ liệu ngầm (background fetch), việc bật cờ này gây hao pin iPhone không cần thiết.

---

### 4. Về trường `badge` trên iOS (Mục 3)
- Nếu Backend gửi cố định `badge: 1`, icon app trên iPhone sẽ luôn bị kẹt ở số 1 (dù người dùng có 10 tin chưa đọc hay đã đọc hết).
- **Đề xuất Backend:**
  - **Phương án tối ưu:** Backend tính số lượng chưa đọc thực tế của user (`unreadCount`) và gửi `badge: unreadCount`. Khi user đã đọc hết tin, push tiếp theo gửi `badge: 0` để xóa badge.
  - **Phương án tạm thời (nếu chưa kịp tính):** Backend có thể **BỎ trường `badge`** trong `aps` (chỉ gửi `alert` và `sound`). Khi người dùng mở app, app sẽ tự hiển thị số lượng chưa đọc nội bộ trong thanh AppBar/BottomBar mà không bị hiện số 1 sai lệch ngoài icon màn hình chính.


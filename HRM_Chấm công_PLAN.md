# KẾ HOẠCH TRIỂN KHAI CHẤM CÔNG (HRM ATTENDANCE PLAN)

> **Tài liệu:** Tóm tắt kỹ thuật & kiến trúc chức năng Chấm công (Attendance - Phase 1)  
> **Nguyên tắc cốt lõi:**  
> - **Check-in / Check-out trực tiếp**: Chỉ thực hiện trên **Mobile App** (kèm xác thực GPS hoặc IP WAN Wi-Fi).  
> - **Web HR**: Đóng vai trò giám sát, đối soát, cấu hình ca/địa điểm và phê duyệt đơn giải trình công (Corrections). Tuyệt đối **không** chấm công thay trên Web.  
> - **Server-authoritative**: Thời gian, IP thực tế và ngày công do Server quyết định; không tin cậy thời gian từ Client gửi lên.

---

## 1. Bản đồ File & Thành phần liên quan trong Hệ thống

- **Màn hình Web HR:**
  - Trang Chấm công: [`packages/features/hrm/src/lib/screens/attendance-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/attendance-screen.tsx) (Route `/attendance` hoặc `/modules/hrm/attendance`).
  - Trang Phê duyệt giải trình công: [`packages/features/hrm/src/lib/screens/approvals-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/approvals-screen.tsx) (Route `/approvals`).
  - Trang Quản lý Ca làm việc: [`packages/features/hrm/src/lib/screens/shifts-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/shifts-screen.tsx) (Route `/shifts`).
- **Giao diện DTO & Hợp đồng Types:** [`packages/contracts/hrm/src/lib/contracts-hrm.ts`](file:///d:/CRM/enterprise-platform/packages/contracts/hrm/src/lib/contracts-hrm.ts)
- **Backend API Controller:** [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts)
- **Database Schema & Migrations:** [`node_modules/@enterprise-platform/worker/dist/migrations/tenant/hrm/0001-hrm.sql`](file:///D:/CRM/enterprise-platform/node_modules/.pnpm/node_modules/@enterprise-platform/worker/dist/migrations/tenant/hrm/0001-hrm.sql)
  - Các bảng: `hrm_schema.attendances`, `hrm_schema.attendance_corrections`, `hrm_schema.attendance_punches`, `hrm_schema.attendance_sites`, `hrm_schema.attendance_network_rules`.

---

## 2. Chi tiết từng Chức năng theo chuẩn Kỹ thuật

### Chức năng 1: Lấy thông tin ngữ cảnh ca làm việc & Giờ chuẩn (Attendance Context)
- **Code chức năng gì:** Cung cấp thông tin ngày làm việc hiện tại, giờ chuẩn Server (NTP), thông tin ca được phân công (`shift`), dung sai đi muộn/về sớm, và gợi ý các địa điểm chấm công (`sites`) phù hợp cho Mobile App/Web.
- **Chức năng đó ở file nào:**
  - Backend: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts) (`@Get('attendance/context')`)
  - Frontend: [`packages/features/hrm/src/lib/screens/attendance-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/attendance-screen.tsx)
- **Sử dụng API gì:** `GET /api/hrm/v1/attendance/context`
- **Payload:** Không có (Truy vấn theo token/session người dùng).
- **Response:**
```json
{
  "data": {
    "server_time": "2026-09-24T08:00:00+07:00",
    "work_date": "2026-09-24",
    "employee": {
      "id": "e83bda91-0000-4000-8000-000000000001",
      "employee_code": "NV-001",
      "full_name": "Nguyễn Văn A"
    },
    "shift": {
      "id": "s1111111-0000-4000-8000-000000000001",
      "code": "CA_HC",
      "name": "Ca Hành chính",
      "start_time": "08:00:00",
      "end_time": "17:30:00",
      "break_minutes": 90,
      "grace_late_minutes": 10,
      "grace_early_minutes": 5
    },
    "allowed_methods": ["GPS", "WIFI_WAN_IP"],
    "sites": [
      {
        "id": "site-01",
        "name": "Trụ sở chính",
        "latitude": 10.776889,
        "longitude": 106.700806,
        "radius_m": 100
      }
    ]
  },
  "meta": { "requestId": "req-ctx-001" }
}
```
- **Màn hình nào trên Web:** `attendance-screen.tsx` (Phần Hero Card hiển thị Ca làm việc, Khung giờ làm, Quy tắc đi muộn/về sớm, Đồng hồ thời gian thực).

---

### Chức năng 2: Kiểm tra trước điều kiện chấm công (Precheck GPS / Wi-Fi)
- **Code chức năng gì:** Mobile App gửi tọa độ GPS hoặc IP Wi-Fi lên để Server kiểm tra trước xem thiết bị có nằm trong vùng cho phép không trước khi cho phép bấm nút quẹt thẻ.
- **Chức năng đó ở file nào:**
  - Backend: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts) (`@Post('attendance/precheck')`)
- **Sử dụng API gì:** `POST /api/hrm/v1/attendance/precheck`
- **Payload:**
```json
{
  "method": "GPS",
  "coordinates": {
    "latitude": 10.776889,
    "longitude": 106.700806,
    "accuracy": 12.5,
    "is_mocked": false
  },
  "wifi_ssid": "SVN_OFFICE_5G"
}
```
- **Response:**
```json
{
  "data": {
    "eligible": true,
    "matched_site": {
      "id": "site-01",
      "name": "Trụ sở chính",
      "distance_m": 15
    },
    "verification_method": "GPS",
    "can_check_in": true,
    "can_check_out": false
  }
}
```
- **Màn hình nào trên Web:** Không có (Dành riêng cho **Mobile App UI** để hiển thị radar quét trạng thái xanh/đỏ trước khi bấm).

---

### Chức năng 3: Quẹt thẻ Vào ca (Check-in) — Mobile App Only
- **Code chức năng gì:** Ghi nhận quẹt thẻ bắt đầu ca làm việc, lưu bằng chứng bất biến vào `hrm_attendance_punches`, tính toán trạng thái (Đúng giờ / Đi muộn) và cập nhật vào `hrm_attendances`.
- **Chức năng đó ở file nào:**
  - Backend Controller: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts) (`@Post('attendance/check-in')`)
  - Contracts DTO: [`packages/contracts/hrm/src/lib/contracts-hrm.ts`](file:///d:/CRM/enterprise-platform/packages/contracts/hrm/src/lib/contracts-hrm.ts) (`CheckInRequest`, `HrmAttendance`)
- **Sử dụng API gì:** `POST /api/hrm/v1/attendance/check-in`
  - *Header bắt buộc:* `Idempotency-Key`, `X-Device-Id`.
- **Payload:**
```json
{
  "employee_id": "e83bda91-0000-4000-8000-000000000001",
  "source": "MOBILE_APP",
  "verification_method": "GPS",
  "device_id": "iphone-uuid-12345",
  "occurred_at": "2026-09-24T07:58:30+07:00",
  "gps_coordinates": {
    "latitude": 10.776889,
    "longitude": 106.700806,
    "accuracy": 14.0,
    "is_mocked": false
  }
}
```
- **Response (Thành công):**
```json
{
  "data": {
    "id": "att-20260924-001",
    "tenant_id": "tenant-uuid-001",
    "employee_id": "e83bda91-0000-4000-8000-000000000001",
    "work_date": "2026-09-24",
    "first_check_in_at": "2026-09-24T07:58:32+07:00",
    "last_check_out_at": null,
    "status": "VALID",
    "late_minutes": 0,
    "attendance_source": "MOBILE_APP",
    "matched_site_name": "Trụ sở chính"
  },
  "meta": { "requestId": "req-in-001" }
}
```
- **Màn hình nào trên Web:** `attendance-screen.tsx`
  - Trên Web hiển thị Banner cảnh báo: **"Chính sách điểm danh di động (Mobile Only) — Tính năng quẹt thẻ trực tiếp trên Web đã bị vô hiệu hóa"**.
  - Sau khi User quẹt trên Mobile, Web tự động cập nhật dòng trạng thái "Hợp lệ / Giờ vào: 07:58".

---

### Chức năng 4: Quẹt thẻ Hết ca (Check-out) — Mobile App Only
- **Code chức năng gì:** Ghi nhận quẹt thẻ kết thúc ca, lưu punch evidence, tính tổng phút làm việc thực tế (`worked_minutes`) trừ đi giờ nghỉ trưa, kiểm tra về sớm (`early_leave_minutes`) và cập nhật `hrm_attendances`.
- **Chức năng đó ở file nào:**
  - Backend Controller: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts) (`@Post('attendance/check-out')`)
  - Contracts DTO: [`packages/contracts/hrm/src/lib/contracts-hrm.ts`](file:///d:/CRM/enterprise-platform/packages/contracts/hrm/src/lib/contracts-hrm.ts) (`CheckOutRequest`)
- **Sử dụng API gì:** `POST /api/hrm/v1/attendance/check-out`
  - *Header bắt buộc:* `Idempotency-Key`, `X-Device-Id`.
- **Payload:**
```json
{
  "employee_id": "e83bda91-0000-4000-8000-000000000001",
  "source": "MOBILE_APP",
  "verification_method": "WIFI_WAN_IP",
  "device_id": "iphone-uuid-12345",
  "occurred_at": "2026-09-24T17:35:10+07:00"
}
```
- **Response:**
```json
{
  "data": {
    "id": "att-20260924-001",
    "employee_id": "e83bda91-0000-4000-8000-000000000001",
    "work_date": "2026-09-24",
    "first_check_in_at": "2026-09-24T07:58:32+07:00",
    "last_check_out_at": "2026-09-24T17:35:10+07:00",
    "worked_minutes": 480,
    "early_leave_minutes": 0,
    "status": "VALID"
  }
}
```
- **Màn hình nào trên Web:** `attendance-screen.tsx` (Cập nhật Sổ chấm công: hiển thị Giờ ra: 17:35, Tổng công: 8h 00m, Trạng thái: Hợp lệ).

---

### Chức năng 5: Xem trạng thái chấm công hôm nay & Lịch sử cá nhân
- **Code chức năng gì:** Truy vấn dữ liệu chấm công ngày hiện tại và danh sách lịch sử theo kỳ/tháng, thống kê số ngày công hợp lệ, đi muộn, về sớm, thiếu quẹt thẻ.
- **Chức năng đó ở file nào:**
  - Backend: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts) (`@Get('attendance')`, `@Get('attendance/today')`)
  - Frontend: [`packages/features/hrm/src/lib/screens/attendance-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/attendance-screen.tsx)
- **Sử dụng API gì:**
  - `GET /api/hrm/v1/attendance/today`
  - `GET /api/hrm/v1/attendance?employee_id={id}&from=2026-09-01&to=2026-09-30`
- **Payload:** Không có (Sử dụng URL query parameters).
- **Response:**
```json
{
  "data": [
    {
      "id": "att-20260924-001",
      "employee_id": "e83bda91-0000-4000-8000-000000000001",
      "work_date": "2026-09-24",
      "check_in_at": "2026-09-24T07:58:32+07:00",
      "check_out_at": "2026-09-24T17:35:10+07:00",
      "attendance_source": "MOBILE_APP",
      "device_id": "iphone-uuid-12345",
      "status": "VALID",
      "worked_minutes": 480,
      "note": null
    }
  ],
  "meta": { "total": 1 }
}
```
- **Màn hình nào trên Web:** `attendance-screen.tsx`
  - Tab **"Ghi nhận giờ làm việc"**: Khối "Tình trạng chấm công hôm nay".
  - Tab **"Lịch sử quẹt thẻ & Sổ chấm công"**: Bảng dữ liệu đa cột, Bộ lọc trạng thái (`Tất cả`, `Hợp lệ`, `Bất thường`, `Đã duyệt sửa`), Thẻ KPI tổng kết (Tổng ngày, Đúng giờ, Đi muộn/Về sớm).

---

### Chức năng 6: Tạo đơn Giải trình / Điều chỉnh công (Attendance Correction)
- **Code chức năng gì:** Cho phép nhân viên làm đơn giải trình khi quên chấm công, thiết bị lỗi, hoặc có việc đột xuất; gửi lên Quản lý trực tiếp phê duyệt theo Workflow.
- **Chức năng đó ở file nào:**
  - Backend: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts) (`@Post('attendance-corrections')`)
  - Frontend: [`packages/features/hrm/src/lib/screens/attendance-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/attendance-screen.tsx) (`handleSendExplain`)
  - Contracts DTO: [`packages/contracts/hrm/src/lib/contracts-hrm.ts`](file:///d:/CRM/enterprise-platform/packages/contracts/hrm/src/lib/contracts-hrm.ts) (`CreateAttendanceCorrectionRequest`)
- **Sử dụng API gì:** `POST /api/hrm/v1/attendance-corrections`
- **Payload:**
```json
{
  "employee_id": "e83bda91-0000-4000-8000-000000000001",
  "attendance_id": "att-20260924-001",
  "request_date": "2026-09-24",
  "new_check_in_at": "2026-09-24T08:00:00+07:00",
  "new_check_out_at": "2026-09-24T17:30:00+07:00",
  "reason": "Quên quẹt thẻ ra do đi công tác đột xuất cuối giờ chiều"
}
```
- **Response:**
```json
{
  "data": {
    "id": "corr-20260924-001",
    "employee_id": "e83bda91-0000-4000-8000-000000000001",
    "request_date": "2026-09-24",
    "status": "PENDING",
    "reason": "Quên quẹt thẻ ra do đi công tác đột xuất cuối giờ chiều",
    "created_at": "2026-09-24T18:00:00+07:00"
  }
}
```
- **Màn hình nào trên Web:** `attendance-screen.tsx` (Bấm nút **"Giải trình công"** tại từng dòng lịch sử công $\rightarrow$ Mở Popup Dialog nhập Giờ đề xuất & Lý do giải trình).

---

### Chức năng 7: Quản lý & Phê duyệt giải trình công (Approve / Reject Correction)
- **Code chức năng gì:** Cấp quản lý/HR rà soát đơn giải trình; khi bấm Duyệt, hệ thống tự động cập nhật lại giờ công trong `hrm_attendances`, đổi trạng thái thành `APPROVED_CORRECTION` và kích hoạt tính toán lại Bảng công (`hrm_timesheets`).
- **Chức năng đó ở file nào:**
  - Backend: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts)
  - Frontend: [`packages/features/hrm/src/lib/screens/approvals-screen.tsx`](file:///d:/CRM/enterprise-platform/packages/features/hrm/src/lib/screens/approvals-screen.tsx)
- **Sử dụng API gì:**
  - Duyệt: `POST /api/hrm/v1/attendance-corrections/{id}/submit`
  - Hủy/Từ chối: `POST /api/hrm/v1/attendance-corrections/{id}/cancel`
  - Tra cứu: `GET /api/hrm/v1/attendance-corrections?status=PENDING`
- **Payload (Khi từ chối):**
```json
{
  "rejection_reason": "Không khớp với lịch đăng ký ra ngoài của phòng ban"
}
```
- **Response (Khi duyệt):**
```json
{
  "data": {
    "id": "corr-20260924-001",
    "status": "APPROVED",
    "approved_at": "2026-09-24T18:10:00+07:00",
    "applied_at": "2026-09-24T18:10:00+07:00",
    "timesheet_updated_at": "2026-09-24T18:10:01+07:00"
  }
}
```
- **Màn hình nào trên Web:** `approvals-screen.tsx` (Tab **"Giải trình chấm công"**, hiển thị danh sách đơn chờ duyệt kèm các nút Thao tác nhanh: *Phê duyệt* hoặc *Từ chối*).

---

### Chức năng 8: Quản trị Địa điểm & Quy tắc Mạng (Attendance Sites & Network Rules)
- **Code chức năng gì:** HR cấu hình tọa độ GPS tâm văn phòng, bán kính cho phép (`radius_m`), độ chính xác GPS tối đa (`max_accuracy_m`) và danh sách dải IP công cộng Wi-Fi (`CIDR Block`) được phép chấm công.
- **Chức năng đó ở file nào:**
  - Database Table: `hrm_schema.attendance_sites`, `hrm_schema.attendance_network_rules` trong [`0001-hrm.sql`](file:///D:/CRM/enterprise-platform/node_modules/.pnpm/node_modules/@enterprise-platform/worker/dist/migrations/tenant/hrm/0001-hrm.sql)
  - Backend: [`packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts`](file:///d:/CRM/enterprise-platform/packages/modules/hrm/src/lib/presentation/hrm-attendance.controller.ts)
- **Sử dụng API gì:**
  - `POST /api/hrm/v1/attendance-sites`
  - `GET /api/hrm/v1/attendance-sites`
  - `POST /api/hrm/v1/attendance-network-rules`
- **Payload tạo Site:**
```json
{
  "code": "SITE_HN_HQ",
  "name": "Trụ sở Hà Nội",
  "latitude": 21.028511,
  "longitude": 105.804817,
  "radius_m": 80,
  "max_accuracy_m": 50,
  "timezone": "Asia/Ho_Chi_Minh",
  "status": "ACTIVE"
}
```
- **Payload tạo Network Rule (IP WAN):**
```json
{
  "site_id": "site-hn-uuid",
  "name": "Wi-Fi Văn phòng Tầng 10",
  "cidr_block": "14.241.120.45/32",
  "ip_version": 4,
  "effective_from": "2026-01-01",
  "status": "ACTIVE"
}
```
- **Response:**
```json
{
  "data": {
    "id": "site-hn-uuid",
    "code": "SITE_HN_HQ",
    "status": "ACTIVE",
    "created_at": "2026-09-24T08:00:00+07:00"
  }
}
```
- **Màn hình nào trên Web:** `attendance-screen.tsx` / Màn hình Cấu hình HRM (Drawer/Dialog thiết lập thông số văn phòng & Wi-Fi theo chuẩn `SearchableSelect` và `antd Table`).

---

## 3. Tổng hợp Bảng API Matrix

| Nghiệp vụ | Kênh sử dụng | Method & API Endpoint | Bảng DB liên quan | File Code xử lý chính |
|---|:---:|---|---|---|
| **Lấy ngữ cảnh & Giờ chuẩn** | App / Web | `GET /api/hrm/v1/attendance/context` | `shift_definitions`, `attendance_sites` | `hrm-attendance.controller.ts` |
| **Kiểm tra trước vị trí (Precheck)** | App | `POST /api/hrm/v1/attendance/precheck` | `attendance_sites`, `attendance_network_rules` | `hrm-attendance.controller.ts` |
| **Check-in Vào ca** | App Only | `POST /api/hrm/v1/attendance/check-in` | `attendance_punches`, `attendances` | `hrm-attendance.controller.ts` |
| **Check-out Ra ca** | App Only | `POST /api/hrm/v1/attendance/check-out` | `attendance_punches`, `attendances` | `hrm-attendance.controller.ts` |
| **Xem trạng thái hôm nay** | App / Web | `GET /api/hrm/v1/attendance/today` | `attendances` | `hrm-attendance.controller.ts` / `attendance-screen.tsx` |
| **Tra cứu sổ lịch sử công** | App / Web | `GET /api/hrm/v1/attendance` | `attendances` | `hrm-attendance.controller.ts` / `attendance-screen.tsx` |
| **Tạo đơn giải trình công** | App / Web | `POST /api/hrm/v1/attendance-corrections` | `attendance_corrections` | `hrm-attendance.controller.ts` / `attendance-screen.tsx` |
| **Phê duyệt giải trình công** | Web HR | `POST /api/hrm/v1/attendance-corrections/{id}/submit` | `attendance_corrections`, `attendances`, `timesheets` | `hrm-attendance.controller.ts` / `approvals-screen.tsx` |
| **Cấu hình Địa điểm (Sites)** | Web HR | `POST /api/hrm/v1/attendance-sites` | `attendance_sites` | `hrm-attendance.controller.ts` |
| **Cấu hình IP WAN Wi-Fi** | Web HR | `POST /api/hrm/v1/attendance-network-rules` | `attendance_network_rules` | `hrm-attendance.controller.ts` |

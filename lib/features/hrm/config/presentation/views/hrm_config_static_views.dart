import 'package:flutter/material.dart';
import '../../../../../models/hrm_models.dart';

/// 1. Cấu hình Quyền và vai trò
class HrmPermissionsConfigView extends StatelessWidget {
  const HrmPermissionsConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'title': 'Quản trị viên hệ thống (Admin)',
        'code': 'SYSTEM_ADMIN',
        'desc': 'Toàn quyền cấu hình, phê duyệt và quản lý toàn bộ phân hệ nhân sự HRM.',
        'users': 2,
        'badge': 'TOÀN QUYỀN',
        'badgeColor': const Color(0xFFEF4444),
      },
      {
        'title': 'Quản lý nhân sự (HR Manager)',
        'code': 'HR_MANAGER',
        'desc': 'Quản lý hồ sơ nhân viên, duyệt đơn từ, tính công, tính lương và cấu hình ca.',
        'users': 4,
        'badge': 'QUẢN LÝ',
        'badgeColor': const Color(0xFF2563EB),
      },
      {
        'title': 'Trưởng phòng / Quản lý trực tiếp',
        'code': 'LINE_MANAGER',
        'desc': 'Theo dõi chấm công, phân ca và phê duyệt cấp 1 cho nhân viên thuộc bộ phận.',
        'users': 8,
        'badge': 'DUYỆT ĐƠN',
        'badgeColor': const Color(0xFFD97706),
      },
      {
        'title': 'Nhân viên (Employee)',
        'code': 'STAFF',
        'desc': 'Chấm công GPS/thiết bị, tạo đơn từ, xem bảng công cá nhân và phiếu lương.',
        'users': 45,
        'badge': 'CÁ NHÂN',
        'badgeColor': const Color(0xFF059669),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...roles.map((r) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        r['title'] as String,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (r['badgeColor'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r['badge'] as String,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r['badgeColor'] as Color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r['desc'] as String,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${r['users']} nhân sự đang gán vai trò này',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// 2. Cấu hình Loại đơn & lý do
class HrmRequestTypesReasonsView extends StatelessWidget {
  const HrmRequestTypesReasonsView({super.key});

  @override
  Widget build(BuildContext context) {
    final types = [
      {
        'title': 'Đơn xin nghỉ phép (Leave)',
        'code': 'LEAVE',
        'icon': Icons.beach_access_rounded,
        'color': const Color(0xFF2563EB),
        'reasons': ['Nghỉ phép năm', 'Nghỉ ốm đau có xác nhận', 'Nghỉ việc riêng hưởng lương (kết hôn/tang chế)', 'Nghỉ không hưởng lương', 'Nghỉ chế độ thai sản'],
      },
      {
        'title': 'Đơn làm thêm giờ (Overtime)',
        'code': 'OVERTIME',
        'icon': Icons.more_time_rounded,
        'color': const Color(0xFFD97706),
        'reasons': ['Làm thêm ngày làm việc bình thường (150%)', 'Làm thêm ngày nghỉ cuối tuần (200%)', 'Làm thêm ngày lễ tết (300%)', 'Trực ca sự cố khẩn cấp'],
      },
      {
        'title': 'Đơn tạm ứng lương (Advance)',
        'code': 'ADVANCE',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFF059669),
        'reasons': ['Tạm ứng chi phí công tác ngoại tỉnh', 'Việc gia đình đột xuất', 'Tạm ứng giữa tháng theo quy chế'],
      },
      {
        'title': 'Đơn điều chỉnh chấm công (Correction)',
        'code': 'CORRECTION',
        'icon': Icons.edit_calendar_rounded,
        'color': const Color(0xFF7C3AED),
        'reasons': ['Quên quẹt thẻ vào/ra', 'Lỗi thiết bị / lỗi kết nối mạng', 'Gặp gỡ khách hàng ngoài văn phòng trước giờ làm', 'Đi công tác khẩn cấp'],
      },
      {
        'title': 'Đơn công tác & điều động (Business Trip)',
        'code': 'BUSINESS_TRIP',
        'icon': Icons.directions_car_outlined,
        'color': const Color(0xFF0284C7),
        'reasons': ['Khảo sát hiện trường trạm & TBA', 'Thí nghiệm kiểm định kỹ thuật', 'Họp đối tác EVN liên tỉnh'],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...types.map((t) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (t['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(t['icon'] as IconData, size: 18, color: t['color'] as Color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t['title'] as String,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t['code'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Danh mục lý do hợp lệ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (t['reasons'] as List<String>).map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(r, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  )).toList(),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// 3. Cấu hình Quy trình duyệt
class HrmApprovalFlowsConfigView extends StatelessWidget {
  const HrmApprovalFlowsConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final flows = [
      {
        'name': 'Quy trình duyệt Đơn xin nghỉ phép',
        'steps': [
          {'step': 'Cấp 1', 'role': 'Quản lý trực tiếp / Trưởng phòng', 'sla': '24 giờ'},
          {'step': 'Cấp 2', 'role': 'Chuyên viên Nhân sự (HR Ops)', 'sla': '12 giờ'},
        ],
      },
      {
        'name': 'Quy trình duyệt Làm thêm giờ (OT)',
        'steps': [
          {'step': 'Cấp 1', 'role': 'Chỉ huy trưởng / Trưởng phòng', 'sla': '12 giờ'},
          {'step': 'Cấp 2', 'role': 'Ban Giám đốc phê duyệt', 'sla': '24 giờ'},
        ],
      },
      {
        'name': 'Quy trình duyệt Tạm ứng lương',
        'steps': [
          {'step': 'Cấp 1', 'role': 'Trưởng bộ phận xác nhận nhu cầu', 'sla': '24 giờ'},
          {'step': 'Cấp 2', 'role': 'Kế toán trưởng đối soát hạn mức', 'sla': '24 giờ'},
          {'step': 'Cấp 3', 'role': 'Tổng Giám đốc ký chi', 'sla': '48 giờ'},
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...flows.map((f) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f['name'] as String,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ...(f['steps'] as List<Map<String, String>>).map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s['step']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s['role']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      ),
                      Text('SLA: ${s["sla"]}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// 4. Cấu hình Lương & OT
class HrmPayrollSettingsConfigView extends StatelessWidget {
  final VoidCallback onOpenPayroll;

  const HrmPayrollSettingsConfigView({
    super.key,
    required this.onOpenPayroll,
  });

  Widget _buildConfigAttributeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Cấu hình bảng lương & Tỷ lệ OT', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Căn cứ Bộ luật Lao động & Quy chế doanh nghiệp SVN', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildConfigAttributeRow('Làm thêm ngày thường', '150% đơn giá lương giờ'),
              _buildConfigAttributeRow('Làm thêm cuối tuần', '200% đơn giá lương giờ'),
              _buildConfigAttributeRow('Làm thêm Lễ, Tết', '300% đơn giá lương giờ (chưa kể lương ngày lễ)'),
              _buildConfigAttributeRow('Phụ cấp ca đêm (22h - 6h)', '+30% đơn giá tiền lương ban ngày'),
              _buildConfigAttributeRow('Mức giảm trừ gia cảnh', 'Bản thân: 11.000.000đ · Phụ thuộc: 4.400.000đ/người'),
              _buildConfigAttributeRow('Tỷ lệ đóng BHXH, BHYT, BHTN', 'Doanh nghiệp: 21.5% · Người lao động: 10.5%'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenPayroll,
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Xem Bảng lương & Chi trả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 5. Hệ thống & Tích hợp thiết bị phần cứng
class HrmSystemIntegrationsConfigView extends StatelessWidget {
  final List<HrmIntegrationDevice> devices;
  final VoidCallback onSyncDevices;

  const HrmSystemIntegrationsConfigView({
    super.key,
    required this.devices,
    required this.onSyncDevices,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hệ thống & Tích hợp phần cứng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Quản lý máy chấm công vân tay / FaceID & Webhook', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF2563EB)),
                tooltip: 'Đồng bộ thiết bị',
                onPressed: onSyncDevices,
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final dev = devices[index];
              final isOnline = dev.status == 'ONLINE';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOnline ? Icons.router_rounded : Icons.signal_wifi_off_rounded,
                        color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dev.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${dev.location} • IP: ${dev.ipAddress}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

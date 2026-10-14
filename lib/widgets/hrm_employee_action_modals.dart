import 'package:flutter/material.dart';
import '../models/hrm_models.dart';
import '../services/hrm_service.dart';
import 'hrm_profile_modals.dart';

/// Reusable Modals for HRM Employee Actions, Decisions, Quick Sheets, and Requests
class HrmEmployeeActionModals {
  static final HrmService _hrmService = HrmService();

  // ==========================================
  // 1. MODAL: EMPLOYEE ACTIONS SHEET (Bottom Action Sheet)
  // ==========================================
  static void showEmployeeActionsSheet(
    BuildContext context,
    HrmEmployeeItem emp, {
    VoidCallback? onRefresh,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    emp.avatarInitials,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.fullName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${emp.code} • ${emp.position} • ${emp.department}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 8),

            // Action 1: Xem hồ sơ nhân sự
            _buildActionItem(
              icon: Icons.badge_outlined,
              title: 'Xem hồ sơ nhân sự chi tiết',
              subtitle: 'Hồ sơ 8 mục, hợp đồng, giấy tờ, gia đình & xuất PDF',
              iconColor: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pop(ctx);
                HrmProfileModals.showEmployeeDetailSheet(context, emp, onRefresh: onRefresh);
              },
            ),

            // Action 2: Tạo quyết định nhân sự
            _buildActionItem(
              icon: Icons.gavel_outlined,
              title: 'Tạo Quyết định Nhân sự',
              subtitle: 'Bổ nhiệm, điều chuyển, nâng lương, khen thưởng/kỷ luật',
              iconColor: const Color(0xFFD97706),
              onTap: () {
                Navigator.pop(ctx);
                showCreateDecisionModal(context, emp);
              },
            ),

            // Action 3: Sửa thông tin nhân viên
            _buildActionItem(
              icon: Icons.edit_outlined,
              title: 'Chỉnh sửa thông tin cơ bản',
              subtitle: 'Cập nhật email, số điện thoại, chức vụ, phòng ban',
              iconColor: const Color(0xFF059669),
              onTap: () {
                Navigator.pop(ctx);
                showEditEmployeeModal(context, emp);
              },
            ),

            // Action 4: Ngừng hoạt động
            _buildActionItem(
              icon: Icons.block_outlined,
              title: 'Ngừng hoạt động / Tạm khóa tài khoản',
              subtitle: 'Chuyển trạng thái nghỉ việc hoặc tạm đình chỉ',
              iconColor: const Color(0xFFDC2626),
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                confirmToggleEmployeeActive(context, emp);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. MODAL: TẠO QUYẾT ĐỊNH NHÂN SỰ
  // ==========================================
  static void showCreateDecisionModal(BuildContext context, HrmEmployeeItem emp) {
    String selectedType = 'APPOINTMENT';
    final codeController = TextEditingController(text: 'QĐ-SVN-${DateTime.now().year}/${emp.code}');
    final descController = TextEditingController();
    final effectiveDateController = TextEditingController(text: _formatDate(DateTime.now()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tạo Quyết định Nhân sự', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text('Áp dụng cho: ${emp.fullName} (${emp.code})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'APPOINTMENT', child: Text('Bổ nhiệm chức danh')),
                    DropdownMenuItem(value: 'TRANSFER', child: Text('Điều chuyển phòng ban / đơn vị')),
                    DropdownMenuItem(value: 'SALARY_RAISE', child: Text('Nâng bậc / Điều chỉnh lương')),
                    DropdownMenuItem(value: 'REWARD_DISCIPLINE', child: Text('Khen thưởng & Kỷ luật')),
                    DropdownMenuItem(value: 'TERMINATION', child: Text('Thôi việc / Chấm dứt HĐLĐ')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                  decoration: const InputDecoration(labelText: 'Loại quyết định *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Số quyết định *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: effectiveDateController,
                  decoration: const InputDecoration(labelText: 'Ngày có hiệu lực *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Trích yếu nội dung quyết định *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã ban hành quyết định ${codeController.text} cho nhân sự ${emp.fullName}!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('BAN HÀNG QUYẾT ĐỊNH', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. MODAL: SỬA THÔNG TIN NHÂN VIÊN
  // ==========================================
  static void showEditEmployeeModal(BuildContext context, HrmEmployeeItem emp) {
    final nameController = TextEditingController(text: emp.fullName);
    final emailController = TextEditingController(text: emp.email);
    final phoneController = TextEditingController(text: emp.phone);
    final posController = TextEditingController(text: emp.position);
    final deptController = TextEditingController(text: emp.department);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sửa Thông tin: ${emp.code}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email công việc', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: posController,
                decoration: const InputDecoration(labelText: 'Chức danh / Vị trí *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptController,
                decoration: const InputDecoration(labelText: 'Đơn vị / Phòng ban *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã cập nhật thông tin nhân sự ${nameController.text} thành công!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('LƯU THAY ĐỔI', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. MODAL: XÁC NHẬN NGỪNG HOẠT ĐỘNG
  // ==========================================
  static void confirmToggleEmployeeActive(BuildContext context, HrmEmployeeItem emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Ngừng hoạt động nhân sự', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn chuyển trạng thái ngừng hoạt động đối với nhân viên ${emp.fullName} (${emp.code})? Tài khoản sẽ bị tạm khóa truy cập vào hệ thống.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã chuyển nhân sự ${emp.fullName} sang trạng thái ngừng hoạt động!'),
                  backgroundColor: const Color(0xFFDC2626),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận Ngừng'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. MODAL: TẠO ĐƠN TỪ / YÊU CẦU MỚI (Leave, OT, Advance, etc.)
  // ==========================================
  static void showCreateRequestModal(
    BuildContext context, {
    VoidCallback? onSubmitted,
  }) {
    HrmRequestType selectedType = HrmRequestType.leave;
    final titleController = TextEditingController();
    final reasonController = TextEditingController();
    final hoursController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tạo Đơn từ / Yêu cầu mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                DropdownButtonFormField<HrmRequestType>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: HrmRequestType.leave, child: Text('Đơn xin nghỉ phép')),
                    DropdownMenuItem(value: HrmRequestType.overtime, child: Text('Đơn đăng ký làm thêm giờ (OT)')),
                    DropdownMenuItem(value: HrmRequestType.advance, child: Text('Đơn đề nghị tạm ứng lương')),
                    DropdownMenuItem(value: HrmRequestType.attendanceCorrection, child: Text('Đơn giải trình quẹt công')),
                    DropdownMenuItem(value: HrmRequestType.shiftChange, child: Text('Đơn xin đổi ca làm việc')),
                    DropdownMenuItem(value: HrmRequestType.businessTrip, child: Text('Đơn đề xuất công tác xa')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                  decoration: const InputDecoration(labelText: 'Loại đơn từ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Lý do chi tiết *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (reasonController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _hrmService.createRequest(
                      type: selectedType,
                      title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Đơn ${selectedType.name}',
                      reason: reasonController.text.trim(),
                      durationHours: double.tryParse(hoursController.text),
                      amount: double.tryParse(amountController.text),
                    );
                    if (onSubmitted != null) onSubmitted();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('GỬI ĐƠN PHÊ DUYỆT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  static Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFFEF2F2) : iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '----';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

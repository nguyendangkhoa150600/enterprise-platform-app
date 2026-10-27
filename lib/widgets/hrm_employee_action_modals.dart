import 'package:flutter/material.dart';
import '../models/hrm_models.dart';
import '../services/hrm_service.dart';
import 'hrm_profile_modals.dart';
import '../core/i18n/app_i18n.dart';

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
              title: 'hrm_modals.employee_action.xem_ho_so_nhan_su_chi'.tr(),
              subtitle: 'hrm_modals.employee_action.ho_so_8_muc_hop_dong'.tr(),
              iconColor: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pop(ctx);
                HrmProfileModals.showEmployeeDetailSheet(context, emp, onRefresh: onRefresh);
              },
            ),

            // Action 2: Tạo quyết định nhân sự
            _buildActionItem(
              icon: Icons.gavel_outlined,
              title: 'hrm_modals.employee_action.tao_quyet_dinh_nhan_su'.tr(),
              subtitle: 'hrm_modals.employee_action.bo_nhiem_dieu_chuyen_nang_luong'.tr(),
              iconColor: const Color(0xFFD97706),
              onTap: () {
                Navigator.pop(ctx);
                showCreateDecisionModal(context, emp);
              },
            ),

            // Action 3: Sửa thông tin nhân viên
            _buildActionItem(
              icon: Icons.edit_outlined,
              title: 'hrm_modals.employee_action.chinh_sua_thong_tin_co_ban'.tr(),
              subtitle: 'hrm_modals.employee_action.cap_nhat_email_so_dien_thoai'.tr(),
              iconColor: const Color(0xFF059669),
              onTap: () {
                Navigator.pop(ctx);
                showEditEmployeeModal(context, emp);
              },
            ),

            // Action 4: Ngừng hoạt động
            _buildActionItem(
              icon: Icons.block_outlined,
              title: 'hrm_modals.employee_action.ngung_hoat_dong_tam_khoa_tai'.tr(),
              subtitle: 'hrm_modals.employee_action.chuyen_trang_thai_nghi_viec_hoac'.tr(),
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
                    Text('hrm_modals.employee_action.tao_quyet_dinh_nhan_su'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text('hrm_modals.employee_action.ap_dung_cho_full_name_code'.tr(args: {'full_name': emp.fullName, 'code': emp.code}), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  menuMaxHeight: 280,
                  borderRadius: BorderRadius.circular(10),
                  items: [
                    DropdownMenuItem(value: 'APPOINTMENT', child: Text('hrm_modals.employee_action.bo_nhiem_chuc_danh'.tr())),
                    DropdownMenuItem(value: 'TRANSFER', child: Text('hrm_modals.employee_action.dieu_chuyen_phong_ban_don_vi'.tr())),
                    DropdownMenuItem(value: 'SALARY_RAISE', child: Text('hrm_modals.employee_action.nang_bac_dieu_chinh_luong'.tr())),
                    DropdownMenuItem(value: 'REWARD_DISCIPLINE', child: Text('hrm_modals.employee_action.khen_thuong_ky_luat'.tr())),
                    DropdownMenuItem(value: 'TERMINATION', child: Text('hrm_modals.employee_action.thoi_viec_cham_dut_hdld'.tr())),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                  decoration: InputDecoration(labelText: 'hrm_modals.employee_action.loai_quyet_dinh'.tr(), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: codeController,
                  decoration: InputDecoration(labelText: 'hrm_modals.employee_action.so_quyet_dinh'.tr(), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: effectiveDateController,
                  decoration: InputDecoration(labelText: 'hrm_modals.employee_action.ngay_co_hieu_luc'.tr(), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'hrm_modals.employee_action.trich_yeu_noi_dung_quyet_dinh'.tr(), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('hrm_modals.employee_action.da_ban_hanh_quyet_dinh_text'.tr(args: {'code': codeController.text, 'full_name': emp.fullName})),
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
                  child: Text('hrm_modals.employee_action.ban_hang_quyet_dinh'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text('hrm_modals.employee_action.sua_thong_tin_code'.tr(args: {'code': emp.code}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'hrm_modals.employee_action.ho_va_ten'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'hrm_modals.employee_action.email_cong_viec'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'hrm_modals.employee_action.so_dien_thoai'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: posController,
                decoration: InputDecoration(labelText: 'hrm_modals.employee_action.chuc_danh_vi_tri'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptController,
                decoration: InputDecoration(labelText: 'hrm_modals.employee_action.don_vi_phong_ban'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('hrm_modals.employee_action.da_cap_nhat_thong_tin_nhan'.tr(args: {'name': nameController.text})),
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
                child: Text('hrm_modals.employee_action.luu_thay_doi'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('hrm_modals.employee_action.ngung_hoat_dong_nhan_su'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('hrm_modals.employee_action.ban_co_chac_chan_muon_chuyen'.tr(args: {'full_name': emp.fullName, 'code': emp.code})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('hrm_modals.employee_action.da_chuyen_nhan_su_full_name'.tr(args: {'full_name': emp.fullName})),
                  backgroundColor: const Color(0xFFDC2626),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: Text('hrm_modals.employee_action.xac_nhan_ngung'.tr()),
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
                Text('hrm_modals.employee_action.tao_don_tu_yeu_cau_moi'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                DropdownButtonFormField<HrmRequestType>(
                  value: selectedType,
                  menuMaxHeight: 280,
                  borderRadius: BorderRadius.circular(10),
                  items: [
                    DropdownMenuItem(value: HrmRequestType.leave, child: Text('hrm_modals.employee_action.don_xin_nghi_phep'.tr())),
                    DropdownMenuItem(value: HrmRequestType.overtime, child: Text('hrm_modals.employee_action.don_dang_ky_lam_them_gio'.tr())),
                    DropdownMenuItem(value: HrmRequestType.advance, child: Text('hrm_modals.employee_action.don_de_nghi_tam_ung_luong'.tr())),
                    DropdownMenuItem(value: HrmRequestType.attendanceCorrection, child: Text('hrm_modals.employee_action.don_giai_trinh_quet_cong'.tr())),
                    DropdownMenuItem(value: HrmRequestType.shiftChange, child: Text('hrm_modals.employee_action.don_xin_doi_ca_lam_viec'.tr())),
                    DropdownMenuItem(value: HrmRequestType.businessTrip, child: Text('hrm_modals.employee_action.don_de_xuat_cong_tac_xa'.tr())),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                  decoration: InputDecoration(labelText: 'hrm_modals.employee_action.loai_don_tu'.tr(), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'hrm_modals.employee_action.ly_do_chi_tiet'.tr(), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (reasonController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _hrmService.createRequest(
                      type: selectedType,
                      title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'hrm_modals.employee_action.don_name'.tr(args: {'name': selectedType.name}),
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
                  child: Text('hrm_modals.employee_action.gui_don_phe_duyet'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
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

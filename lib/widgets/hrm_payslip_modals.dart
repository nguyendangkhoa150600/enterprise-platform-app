import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hrm_attendance_service.dart';
import '../services/pdf_export_service.dart';

/// Reusable Modals for Payslip Breakdown and Employee Profile Corrections
class HrmPayslipModals {
  static final HrmAttendanceService _service = HrmAttendanceService();

  // ==========================================
  // 1. MODAL: CHI TIẾT PHIẾU LƯƠNG & BẢNG KÊ (Payslip Item Breakdown)
  // ==========================================
  static void showPayslipBreakdownSheet(
    BuildContext context,
    Map<String, dynamic> item, {
    Map<String, dynamic>? profile,
  }) {
    final snapshot = item['snapshotJson'] is Map<String, dynamic> ? item['snapshotJson'] as Map<String, dynamic> : <String, dynamic>{};
    final periodInfo = snapshot['period'] is Map<String, dynamic> ? snapshot['period'] as Map<String, dynamic> : <String, dynamic>{};
    final totalInfo = snapshot['total'] is Map<String, dynamic> ? snapshot['total'] as Map<String, dynamic> : <String, dynamic>{};
    final itemsList = snapshot['items'] is List ? snapshot['items'] as List : [];

    final payslipNo = item['payslipNumber'] ?? item['payslip_number'] ?? 'PS-001';
    final periodCode = periodInfo['code'] ?? item['periodCode'] ?? item['period_code'] ?? 'KY-LUONG';
    final fromDate = periodInfo['from_date'] ?? item['from_date'] ?? '----';
    final toDate = periodInfo['to_date'] ?? item['to_date'] ?? '----';
    final netSalary = totalInfo['net_salary'] ?? item['netSalary'] ?? item['net_salary'] ?? 0;
    final grossSalary = totalInfo['gross_salary'] ?? item['baseSalary'] ?? item['base_salary'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Modal Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chi tiết Phiếu lương $payslipNo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('Kỳ $periodCode ($fromDate - $toDate)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('THỰC LĨNH (NET)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatCurrency(netSalary)} đ',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('TỔNG THU NHẬP (GROSS)', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatCurrency(grossSalary)} đ',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section: Bảng kê chi tiết
                    const Text('BẢNG KÊ THU NHẬP & KHẤU TRỪ CHI TIẾT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(height: 8),

                    if (itemsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text('Chưa có bảng kê chi tiết từng mục cho phiếu lương này.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: itemsList.map<Widget>((subItem) {
                            final name = subItem['item_name'] ?? subItem['name'] ?? 'Mục lương';
                            final category = subItem['category'] ?? 'EARNING';
                            final amount = subItem['amount'] ?? 0;
                            final isDeduction = category.toString().toUpperCase().contains('DEDUCT') || name.toString().contains('BHXH') || name.toString().contains('Thuế') || name.toString().contains('Khấu trừ');

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isDeduction ? Icons.remove_circle_outline : Icons.add_circle_outline,
                                        size: 16,
                                        color: isDeduction ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(name.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  Text(
                                    '${isDeduction ? "-" : "+"}${_formatCurrency(amount)} đ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDeduction ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        PdfExportService.exportPayslipPdf(
                          payslip: item,
                          employeeName: profile?['fullName'] ?? 'Nguyễn Trần Như Quỳnh',
                          employeeCode: profile?['code'] ?? 'NV-2026',
                          department: profile?['department'] ?? 'Phòng Kỹ thuật & Nghiên cứu',
                          position: profile?['position'] ?? 'Chuyên viên Phân tích Dữ liệu',
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('In / Xuất PDF Phiếu lương'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Đóng', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. MODAL: ĐỀ NGHỊ CHỈNH SỬA THÔNG TIN CÁ NHÂN
  // ==========================================
  static void showProfileCorrectionDialog(
    BuildContext context, {
    required Map<String, dynamic>? profile,
    required Function(Map<String, String>) onSubmit,
  }) {
    String selectedField = 'Họ và tên';
    final currentValCtrl = TextEditingController(text: profile?['fullName']?.toString() ?? 'Nguyễn Trần Như Quỳnh');
    final newValCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    final fields = [
      'Họ và tên',
      'Ngày sinh',
      'Giới tính',
      'Số CCCD / CMND',
      'Ngày cấp CCCD',
      'Nơi cấp CCCD',
      'Quốc tịch / Dân tộc',
      'Tình trạng hôn nhân',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Đề nghị chỉnh sửa thông tin',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                  ],
                ),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                // Field Selector
                const Text('Trường thông tin cần điều chỉnh *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedField,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: fields.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedField = val;
                            if (val == 'Họ và tên') {
                              currentValCtrl.text = profile?['fullName']?.toString() ?? '';
                            } else if (val == 'Ngày sinh') {
                              currentValCtrl.text = profile?['dateOfBirth']?.toString() ?? '';
                            } else if (val == 'Giới tính') {
                              currentValCtrl.text = profile?['gender']?.toString() ?? 'Nam';
                            } else if (val == 'Số CCCD / CMND') {
                              currentValCtrl.text = profile?['idNumber']?.toString() ?? profile?['citizenIdNumber']?.toString() ?? '';
                            } else if (val == 'Tình trạng hôn nhân') {
                              currentValCtrl.text = profile?['maritalStatus']?.toString() ?? 'Độc thân';
                            } else {
                              currentValCtrl.text = '';
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Giá trị hiện tại
                _buildModalTextField(
                  label: 'Giá trị hiện tại',
                  controller: currentValCtrl,
                  readOnly: true,
                ),
                const SizedBox(height: 10),

                // Giá trị mới đề xuất
                _buildModalTextField(
                  label: 'Giá trị mới đề xuất *',
                  controller: newValCtrl,
                  hintText: 'Nhập thông tin chính xác cần sửa',
                ),
                const SizedBox(height: 10),

                // Lý do điều chỉnh
                _buildModalTextField(
                  label: 'Lý do điều chỉnh *',
                  controller: reasonCtrl,
                  hintText: 'Ví dụ: Cập nhật theo CCCD mới làm lại...',
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (newValCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng nhập giá trị mới và lý do.'), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                            await _service.createCorrection(
                              requestDate: today,
                              newCheckInAt: '${today}T08:00:00',
                              newCheckOutAt: '${today}T17:30:00',
                              reason: '[Đính chính hồ sơ: $selectedField -> ${newValCtrl.text.trim()}] ${reasonCtrl.text.trim()}',
                            );

                            Navigator.pop(ctx);
                            onSubmit({
                              'field': selectedField,
                              'newValue': newValCtrl.text.trim(),
                              'reason': reasonCtrl.text.trim(),
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã gửi đề nghị chỉnh sửa thông tin đến Nhân sự!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isSubmitting ? 'Đang gửi...' : 'Gửi đề xuất chỉnh sửa', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildModalTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(fontSize: 12.5, color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }

  static String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final num? val = num.tryParse(amount.toString());
    if (val == null) return '0';
    return NumberFormat('#,###', 'vi_VN').format(val);
  }
}

import 'package:flutter/material.dart';
import '../../../../../models/hrm_personnel_decision_model.dart';
import '../../../../../utils/user_resolver.dart';

class PersonnelDecisionDetailSheet extends StatefulWidget {
  final HrmPersonnelDecision decision;
  final VoidCallback? onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const PersonnelDecisionDetailSheet({
    super.key,
    required this.decision,
    this.onEdit,
    this.onApprove,
    this.onReject,
    this.onCancel,
    this.onRetry,
  });

  static void show(
    BuildContext context, {
    required HrmPersonnelDecision decision,
    VoidCallback? onEdit,
    VoidCallback? onApprove,
    VoidCallback? onReject,
    VoidCallback? onCancel,
    VoidCallback? onRetry,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PersonnelDecisionDetailSheet(
        decision: decision,
        onEdit: onEdit,
        onApprove: onApprove,
        onReject: onReject,
        onCancel: onCancel,
        onRetry: onRetry,
      ),
    );
  }

  @override
  State<PersonnelDecisionDetailSheet> createState() => _PersonnelDecisionDetailSheetState();
}

class _PersonnelDecisionDetailSheetState extends State<PersonnelDecisionDetailSheet> {
  @override
  void initState() {
    super.initState();
    UserResolver.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _resolveUserName(String? id, String? name, String? email) {
    if (name != null && name.trim().isNotEmpty && name != 'Người dùng') {
      if (email != null && email.trim().isNotEmpty && email != name) {
        return '$name ($email)';
      }
      return name;
    }
    if (email != null && email.trim().isNotEmpty) {
      return email;
    }
    return UserResolver.resolve(id);
  }

  String _formatMoney(double? val) {
    if (val == null) return '----';
    return '${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '----';
    if (iso.length >= 10) {
      return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
    }
    return iso;
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    final onEdit = widget.onEdit;
    final onApprove = widget.onApprove;
    final onReject = widget.onReject;
    final onCancel = widget.onCancel;
    final onRetry = widget.onRetry;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            decision.decisionNo,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: decision.statusBgColor,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: decision.statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              decision.statusLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: decision.statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quyết định ${decision.typeLabel.toLowerCase()} nhân sự',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. NHÂN VIÊN & HIỆU LỰC
                  _buildSectionHeader('1. THÔNG TIN NHÂN SỰ'),
                  _buildCard([
                    _buildDataRow('Nhân viên:', decision.employeeName ?? '----'),
                    _buildDataRow('Mã nhân viên:', decision.employeeCode ?? '----'),
                    _buildDataRow('Loại quyết định:', decision.typeLabel, valueColor: const Color(0xFF2563EB)),
                    _buildDataRow('Ngày hiệu lực:', _formatDate(decision.effectiveDate), isLast: true),
                  ]),
                  const SizedBox(height: 14),

                  // 2. THAY ĐỔI VỊ TRÍ & ĐƠN VỊ
                  _buildSectionHeader('2. THAY ĐỔI VỊ TRÍ & ĐƠN VỊ'),
                  _buildCard([
                    _buildComparisonRow(
                      label: 'Chức danh:',
                      before: decision.fromPositionName ?? '----',
                      after: decision.toPositionName ?? '----',
                    ),
                    _buildComparisonRow(
                      label: 'Phòng ban / Đơn vị:',
                      before: decision.fromUnitName ?? '----',
                      after: decision.toUnitName ?? '----',
                    ),
                    _buildComparisonRow(
                      label: 'Quản lý trực tiếp:',
                      before: decision.fromManagerName ?? '----',
                      after: decision.toManagerName ?? 'Không có',
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // 3. THAY ĐỔI LƯƠNG
                  _buildSectionHeader('3. ĐIỀU CHỈNH TIỀN LƯƠNG'),
                  _buildCard([
                    _buildDataRow('Có thay đổi lương:', decision.salaryChanged ? 'Có điều chỉnh' : 'Giữ nguyên',
                        valueColor: decision.salaryChanged ? const Color(0xFF059669) : const Color(0xFF64748B)),
                    if (decision.salaryChanged) ...[
                      _buildComparisonRow(
                        label: 'Lương cơ bản:',
                        before: _formatMoney(decision.fromBaseSalary),
                        after: _formatMoney(decision.toBaseSalary),
                      ),
                      if (decision.toSalaryType != null)
                        _buildDataRow('Loại lương:', decision.toSalaryType == 'GROSS' ? 'Gross' : 'Net'),
                    ],
                  ]),
                  const SizedBox(height: 14),

                  // 4. LÝ DO & CĂN CỨ
                  _buildSectionHeader('4. CĂN CỨ & LÝ DO'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      decision.reason.trim().isNotEmpty ? decision.reason : 'Không có ghi chú lý do.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. TIẾN TRÌNH ÁP DỤNG
                  _buildSectionHeader('5. TIẾN TRÌNH ÁP DỤNG HỒ SƠ'),
                  _buildCard([
                    _buildStepRow('Chức danh (Core):', decision.appliedSteps['core'] == true || decision.status == 'APPLIED'),
                    _buildStepRow('Hồ sơ lương:', decision.appliedSteps['salary'] == true || decision.status == 'APPLIED', isLast: true),
                  ]),
                  const SizedBox(height: 14),

                  // 6. NHẬT KÝ & DUYỆT
                  _buildSectionHeader('6. THỜI GIAN & PHÊ DUYỆT'),
                  _buildCard([
                    if (decision.createdBy != null)
                      _buildDataRow(
                        'Người tạo:',
                        _resolveUserName(decision.createdBy, decision.createdByName, decision.createdByEmail),
                      ),
                    _buildDataRow('Ngày tạo:', _formatDate(decision.createdAt)),
                    if (decision.approvedBy != null)
                      _buildDataRow(
                        'Người duyệt:',
                        _resolveUserName(decision.approvedBy, decision.approvedByName, decision.approvedByEmail),
                      ),
                    if (decision.approvedAt != null) _buildDataRow('Ngày duyệt:', _formatDate(decision.approvedAt)),
                    if (decision.appliedAt != null) _buildDataRow('Thời gian áp dụng:', _formatDate(decision.appliedAt)),
                    if (decision.rejectedReason != null && decision.rejectedReason!.isNotEmpty)
                      _buildDataRow('Lý do từ chối:', decision.rejectedReason!, valueColor: const Color(0xFFDC2626)),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Footer Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                if (decision.canEdit && onEdit != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit.call();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (decision.canApprove && onReject != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onReject.call();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        foregroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (decision.canApprove && onApprove != null) ...[
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onApprove.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Duyệt & Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                if (decision.canCancel && onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onCancel.call();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        foregroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Hủy quyết định', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    ),
                  ),
                ],
                if (decision.canRetry && onRetry != null) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onRetry.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Thử lại áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDataRow(String label, String value, {Color? valueColor, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String before,
    required String after,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  before,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        after,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String label, bool isApplied, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Icon(
            isApplied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isApplied ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
          const Spacer(),
          Text(
            isApplied ? 'Đã hoàn tất' : 'Chưa áp dụng',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isApplied ? const Color(0xFF059669) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

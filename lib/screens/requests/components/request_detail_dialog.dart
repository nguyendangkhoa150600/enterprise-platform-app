import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../providers/auth_provider.dart';

void showCorrectionDetailDialog({
  required BuildContext context,
  required AttendanceCorrection c,
  AttendanceContext? attendanceContext,
  required Future<void> Function(AttendanceCorrection) onCancelRequest,
}) {
  final auth = context.read<AuthProvider>();

  // Determine Creator Info
  final creatorName = (c.employeeName != null && c.employeeName!.isNotEmpty)
      ? c.employeeName!
      : ((attendanceContext != null && attendanceContext.fullName.isNotEmpty)
          ? attendanceContext.fullName
          : (auth.fullName?.isNotEmpty == true ? auth.fullName! : 'Nhân viên'));

  final creatorCode = (c.employeeCode != null && c.employeeCode!.isNotEmpty)
      ? c.employeeCode!
      : ((attendanceContext != null && attendanceContext.employeeCode.isNotEmpty)
          ? attendanceContext.employeeCode
          : '');

  final creatorDept = (c.department != null && c.department!.isNotEmpty)
      ? c.department!
      : ((attendanceContext != null && attendanceContext.department != null && attendanceContext.department!.isNotEmpty)
          ? attendanceContext.department!
          : '');

  // Format creation time: dd/MM/yyyy HH:mm
  String formattedCreatedAt = '';
  try {
    final dt = DateTime.tryParse(c.createdAt)?.toLocal();
    if (dt != null) {
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      formattedCreatedAt = '$d/$m/$y $h:$min';
    } else {
      formattedCreatedAt = c.createdAt;
    }
  } catch (_) {
    formattedCreatedAt = c.createdAt;
  }

  // Kind Icon & Styling (Matching Web 1:1)
  IconData kindIcon = Icons.description_outlined;
  Color kindBoxColor = const Color(0xFFF1F5F9);
  Color kindColor = const Color(0xFF475569);

  if (c.kind == 'ot') {
    kindIcon = Icons.access_time_rounded;
    kindBoxColor = const Color(0xFFEDE9FE);
    kindColor = const Color(0xFF7C3AED);
  } else if (c.kind == 'leave') {
    kindIcon = Icons.calendar_today_outlined;
    kindBoxColor = const Color(0xFFECFDF5);
    kindColor = const Color(0xFF059669);
  } else if (c.kind == 'business_trip') {
    kindIcon = Icons.business_center_outlined;
    kindBoxColor = const Color(0xFFFFF7ED);
    kindColor = const Color(0xFFEA580C);
  } else if (c.kind == 'shift_change') {
    kindIcon = Icons.swap_horiz_rounded;
    kindBoxColor = const Color(0xFFF0FDFA);
    kindColor = const Color(0xFF0D9488);
  } else if (c.kind == 'correction') {
    kindIcon = Icons.description_outlined;
    kindBoxColor = const Color(0xFFFFF1F2);
    kindColor = const Color(0xFFE11D48);
  } else if (c.kind == 'advance') {
    kindIcon = Icons.account_balance_wallet_outlined;
    kindBoxColor = const Color(0xFFEEF2FF);
    kindColor = const Color(0xFF4F46E5);
  }

  // Status Meta
  Color statusBg = const Color(0xFFFEF3C7);
  Color statusBorder = const Color(0xFFFDE68A);
  Color statusText = const Color(0xFFD97706);
  String statusLabel = c.kind == 'ot' ? 'Chờ duyệt OT' : 'Chờ duyệt';

  if (c.status == 'APPROVED') {
    statusBg = const Color(0xFFECFDF5);
    statusBorder = const Color(0xFFA7F3D0);
    statusText = const Color(0xFF059669);
    statusLabel = c.kind == 'ot' ? 'Đã duyệt OT' : 'Đã duyệt';
  } else if (c.status == 'REJECTED') {
    statusBg = const Color(0xFFFEF2F2);
    statusBorder = const Color(0xFFFECDD3);
    statusText = const Color(0xFFDC2626);
    statusLabel = 'Đã từ chối';
  } else if (c.status == 'CANCELLED') {
    statusBg = const Color(0xFFF1F5F9);
    statusBorder = const Color(0xFFE2E8F0);
    statusText = const Color(0xFF64748B);
    statusLabel = 'Đã rút / hủy';
  }

  final displayTitle = c.typeName ?? 'Đơn từ';
  final displayCode = (c.code != null && c.code!.isNotEmpty)
      ? c.code!
      : (c.id.length >= 8 ? c.id.substring(0, 8).toUpperCase() : c.id.toUpperCase());

  final displayPeriod = (c.effectiveDate != null && c.effectiveDate!.isNotEmpty)
      ? c.effectiveDate!
      : '${c.fromDate ?? c.requestDate} - ${c.toDate ?? c.requestDate}';

  final displayDuration = (c.durationText != null && c.durationText!.isNotEmpty)
      ? c.durationText!
      : (c.duration != null ? '${c.duration} ngày' : '—');

  // Related Project info if present
  String? projectName;
  String? projectCode;
  if (c.rawDetails != null) {
    projectName = c.rawDetails!['projectName']?.toString() ??
        c.rawDetails!['project_name']?.toString() ??
        (c.rawDetails!['project'] is Map ? c.rawDetails!['project']['name']?.toString() : null);
    projectCode = c.rawDetails!['projectCode']?.toString() ??
        c.rawDetails!['project_code']?.toString() ??
        (c.rawDetails!['project'] is Map ? c.rawDetails!['project']['code']?.toString() : null);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Top Header: Chi tiết đơn & Status badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết đơn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: statusText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Kind Identity Banner
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kindBoxColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(kindIcon, size: 22, color: kindColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Text(
                                    'Mã đơn: ',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    displayCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // 2. Field Details Grid (Matching Web DetailField 1:1)
                    _buildDetailField('Thời gian', displayPeriod),
                    _buildDetailField('Thời lượng', displayDuration),
                    _buildDetailField('Lý do', c.reason),
                    _buildDetailField('Mô tả', c.description),
                    if (projectName != null && projectName.isNotEmpty)
                      _buildDetailField(
                        'Dự án liên quan',
                        projectCode != null && projectCode.isNotEmpty
                            ? '$projectName ($projectCode)'
                            : projectName,
                      ),
                    _buildDetailField(
                      'Người tạo',
                      '$creatorName${creatorCode.isNotEmpty ? ' ($creatorCode)' : ''}',
                      subtitle: creatorDept.isNotEmpty ? creatorDept : null,
                    ),
                    _buildDetailField('Ngày tạo', formattedCreatedAt),
                    if (c.rejectionReason != null && c.rejectionReason!.isNotEmpty)
                      _buildDetailField('Lý do từ chối', c.rejectionReason!, isDanger: true),

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),

                    // 3. Quy trình phê duyệt (TIẾN ĐỘ QUY TRÌNH - Matching Web)
                    const Text(
                      'Quy trình phê duyệt',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'TIẾN ĐỘ QUY TRÌNH',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step 1: Nhân viên khởi tạo yêu cầu
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD1FAE5),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.check, size: 14, color: Color(0xFF059669)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Nhân viên khởi tạo yêu cầu',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$creatorName — $formattedCreatedAt',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Vertical Connector
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Container(
                              width: 1.5,
                              height: 20,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),

                          // Step 2: Người duyệt
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: c.status == 'APPROVED'
                                      ? const Color(0xFFD1FAE5)
                                      : c.status == 'REJECTED'
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: c.status == 'APPROVED'
                                    ? const Icon(Icons.check, size: 14, color: Color(0xFF059669))
                                    : c.status == 'REJECTED'
                                        ? const Icon(Icons.close, size: 14, color: Color(0xFFDC2626))
                                        : Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFD97706),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Người duyệt',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.approver ?? 'Hà Nguyên Hoàng',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.status == 'APPROVED'
                                          ? 'Đã chấp thuận'
                                          : c.status == 'REJECTED'
                                              ? 'Đã từ chối'
                                              : c.status == 'CANCELLED'
                                                  ? 'Đã rút / hủy'
                                                  : 'Đang chờ xét duyệt (SLA 24h)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.status == 'APPROVED'
                                            ? const Color(0xFF059669)
                                            : c.status == 'REJECTED'
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF64748B),
                                        fontWeight: c.status != 'PENDING' ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),

                    // 4. Trao đổi và ý kiến (0) (Matching Web 1:1)
                    Row(
                      children: const [
                        Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Trao đổi và ý kiến (0)',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Text(
                        'Chưa có trao đổi nào. Gõ @ để nhắc tên người cần xem đơn này.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Viết trao đổi... gõ @ để nhắc người liên quan...',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF94A3B8)),
                          SizedBox(width: 8),
                          Icon(Icons.send_rounded, size: 16, color: Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Pinned Bottom Actions Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  if (c.status == 'PENDING') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await onCancelRequest(c);
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Thu hồi đơn',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Xem đầy đủ chi tiết',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildDetailField(String label, String value, {String? subtitle, bool isDanger = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

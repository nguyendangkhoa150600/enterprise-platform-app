import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_models.dart';
import 'request_cards.dart';

void showCorrectionDetailDialog({
  required BuildContext context,
  required AttendanceCorrection c,
  required Future<void> Function(AttendanceCorrection) onCancelRequest,
}) {
  String title = 'Đơn xin nghỉ phép';
  String cleanReason = c.reason;
  if (c.leaveTypeName != null && c.leaveTypeName!.isNotEmpty) {
    title = c.leaveTypeName!;
  } else {
    final match = RegExp(r'^\[(.*?)\]').firstMatch(c.reason);
    if (match != null) {
      title = match.group(1)!;
      cleanReason = c.reason.substring(match.end).trim();
    }
  }
  if (cleanReason.isEmpty) cleanReason = c.reason;

  final code = c.id.length >= 8 ? c.id.substring(c.id.length - 8).toUpperCase() : (c.id.isNotEmpty ? c.id.toUpperCase() : '8E86BF8B');

  String statusLabel = 'Chờ phê duyệt';
  Color statusBg = const Color(0xFFFEF3C7);
  Color statusText = const Color(0xFFD97706);

  if (c.status == 'APPROVED') {
    statusLabel = 'Đã phê duyệt';
    statusBg = const Color(0xFFECFDF5);
    statusText = const Color(0xFF059669);
  } else if (c.status == 'REJECTED') {
    statusLabel = 'Bị từ chối';
    statusBg = const Color(0xFFFEF2F2);
    statusText = const Color(0xFFDC2626);
  } else if (c.status == 'CANCELLED') {
    statusLabel = 'Đã hủy đơn';
    statusBg = const Color(0xFFF1F5F9);
    statusText = const Color(0xFF64748B);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$code · $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('Tạo lúc: ${formatRequestDate(c.createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusText)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Detail items
            buildRequestDetailRow('Thời gian:', '${formatRequestDate(c.fromDate ?? c.requestDate)} đến ${formatRequestDate(c.toDate ?? c.requestDate)}'),
            if (c.duration != null)
              buildRequestDetailRow('Số ngày áp dụng:', '${c.duration!.toStringAsFixed(c.duration! % 1 == 0 ? 0 : 1)} ngày'),
            buildRequestDetailRow('Lý do đề xuất:', cleanReason),
            if (c.rejectionReason != null && c.rejectionReason!.isNotEmpty)
              buildRequestDetailRow('Lý do từ chối:', c.rejectionReason!, isHighlighted: true),

            const SizedBox(height: 18),
            if (c.status == 'PENDING')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await onCancelRequest(c);
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Hủy bỏ yêu cầu này', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

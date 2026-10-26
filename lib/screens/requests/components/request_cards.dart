import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/hrm_attendance_models.dart';

String formatRequestDate(String isoString) {
  final dt = DateTime.tryParse(isoString);
  if (dt == null) return isoString;
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

Widget buildRequestDetailRow(String label, String value, {bool isHighlighted = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? const Color(0xFFD97706) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    ),
  );
}

// ==========================================
// CATALOG CARD (100% MATCHING WEB UI)
// ==========================================
class RequestCatalogCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String badgeText;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final String title;
  final String description;
  final String infoBoxText;
  final String buttonText;
  final VoidCallback onTap;

  const RequestCatalogCard({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.badgeText,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.title,
    required this.description,
    required this.infoBoxText,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              infoBoxText,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1B4B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CORRECTION CARD (MATCHING WEB UI)
// ==========================================
class RequestCorrectionCard extends StatelessWidget {
  final AttendanceCorrection c;
  final VoidCallback onTap;

  const RequestCorrectionCard({
    super.key,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFD97706);
    String statusLabel = 'requests.status.pending'.tr();
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (c.status == 'APPROVED') {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF059669);
      statusLabel = 'requests.status.approved'.tr();
      statusIcon = Icons.check_circle_rounded;
    } else if (c.status == 'REJECTED') {
      statusBg = const Color(0xFFFEF2F2);
      statusText = const Color(0xFFDC2626);
      statusLabel = 'requests.status.rejected'.tr();
      statusIcon = Icons.cancel_rounded;
    } else if (c.status == 'CANCELLED') {
      statusBg = const Color(0xFFF1F5F9);
      statusText = const Color(0xFF64748B);
      statusLabel = 'requests.status.cancelled'.tr();
      statusIcon = Icons.remove_circle_outline;
    }

    String title = 'requests.type.leave'.tr();
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$code',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusText),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    '${formatRequestDate(c.fromDate ?? c.requestDate)} - ${formatRequestDate(c.toDate ?? c.requestDate)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                  if (c.duration != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'requests.card.days_paren'.tr(args: {'count': c.duration!.toStringAsFixed(c.duration! % 1 == 0 ? 0 : 1)}),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Text(
                  'requests.card.reason'.tr(args: {'reason': cleanReason}),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'common.view_detail'.tr(),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2563EB)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DRAFT CARD WIDGET
// ==========================================
class RequestDraftCard extends StatelessWidget {
  final AttendanceCorrection draft;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const RequestDraftCard({
    super.key,
    required this.draft,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    String draftType = 'requests.card.draft_type_default'.tr();
    String draftReason = draft.reason;
    final match = RegExp(r'^\[(.*?)\]').firstMatch(draft.reason);
    if (match != null) {
      draftType = match.group(1)!;
      draftReason = draft.reason.substring(match.end).trim();
    } else if (draft.leaveTypeName != null && draft.leaveTypeName!.isNotEmpty) {
      draftType = draft.leaveTypeName!;
    }
    if (draftReason.isEmpty) draftReason = 'requests.card.no_reason'.tr();

    final draftCode = draft.id.length >= 8 ? draft.id.substring(draft.id.length - 8).toUpperCase() : draft.id.toUpperCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$draftCode',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    draftType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('requests.card.draft_badge'.tr(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('requests.card.reason'.tr(args: {'reason': draftReason}), style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                label: Text('common.delete'.tr(), style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text('requests.card.continue_edit_submit'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

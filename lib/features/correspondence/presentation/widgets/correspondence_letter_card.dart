import 'package:flutter/material.dart';
import '../../domain/models/correspondence_models.dart';

/// Reusable card displaying an Incoming or Outgoing Letter in list views
class CorrespondenceLetterCard extends StatelessWidget {
  final LetterSummary letter;
  final String today;
  final VoidCallback? onTap;

  const CorrespondenceLetterCard({
    super.key,
    required this.letter,
    required this.today,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = letter.direction == 'outgoing';
    final due = CorrespondenceDateUtils.dueText(letter.dueOn, letter.stage, today);
    final displayNo = isOutgoing
        ? (letter.displayNo.isNotEmpty
            ? letter.displayNo
            : (letter.outgoingNo != null && letter.outgoingNo!.isNotEmpty
                ? letter.outgoingNo!
                : 'Chưa cấp số'))
        : (letter.incomingNo.isNotEmpty
            ? letter.incomingNo
            : (letter.displayNo.isNotEmpty ? letter.displayNo : 'Chưa cấp số'));

    final letterDate = isOutgoing && letter.publishedOn != null && letter.publishedOn!.isNotEmpty
        ? CorrespondenceDateUtils.formatDay(letter.publishedOn!)
        : (letter.receivedOn.isNotEmpty
            ? CorrespondenceDateUtils.formatDay(letter.receivedOn)
            : null);

    final isArchived = letter.stage == 'archived';
    final isCancelled = letter.stage == 'cancelled';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top row: Số đến + Ngày đến + Độ khẩn + Hạn xử lý
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Badge Số đến
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF), // Sky 50
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        displayNo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1), // Sky 700
                        ),
                      ),
                    ),
                    if (letterDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        letterDate,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                    const Spacer(),

                    // Độ khẩn Pill
                    _buildUrgencyPill(),

                    // Hạn xử lý Pill
                    if (due != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: due.bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          due.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: due.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Trích yếu (Subject)
                Text(
                  letter.subject.isNotEmpty ? letter.subject : '(Không có trích yếu)',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Người gửi / Đơn vị soạn & Nơi nhận (cho công văn đi) hoặc Cơ quan gửi (cho công văn đến)
                if (isOutgoing) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.send_rounded, size: 14, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            children: [
                              TextSpan(
                                text: letter.outgoingSenderText,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                              if (letter.recipient != null && letter.recipient!.isNotEmpty) ...[
                                const TextSpan(
                                  text: ' → ',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                ),
                                TextSpan(
                                  text: letter.recipient!,
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else if (letter.senderOrg.isNotEmpty || (letter.senderRef != null && letter.senderRef!.isNotEmpty)) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.business_outlined, size: 14, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            children: [
                              TextSpan(
                                text: letter.senderOrg.isNotEmpty ? letter.senderOrg : '',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              if (letter.senderRef != null && letter.senderRef!.isNotEmpty) ...[
                                const TextSpan(
                                  text: ' · ',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                TextSpan(
                                  text: letter.senderRef!,
                                  style: const TextStyle(color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // 4. Bottom Row: Bước xử lý & Người đảm nhận + Arrow
                Row(
                  children: [
                    // Bước xử lý Badge
                    _buildStageBadge(isArchived, isCancelled),

                    // Người xử lý hiện tại (nếu có)
                    if (letter.currentAssigneeNames.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          letter.currentAssigneeNames.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),

                    // Xem chi tiết >
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Chi tiết',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencyPill() {
    Color dotColor = const Color(0xFF3B82F6); // Blue
    Color textColor = const Color(0xFF334155);

    if (letter.urgency == 'urgent') {
      dotColor = const Color(0xFFF59E0B); // Amber
      textColor = const Color(0xFFD97706);
    } else if (letter.urgency == 'emergency') {
      dotColor = const Color(0xFFEF4444); // Red
      textColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4.5),
          Text(
            letter.urgencyName.isNotEmpty ? letter.urgencyName : 'Thường',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStageBadge(bool isArchived, bool isCancelled) {
    Color bgColor = const Color(0xFFFEF3C7); // Amber 100
    Color textColor = const Color(0xFF92400E); // Amber 800
    Color dotColor = const Color(0xFFD97706);

    if (isArchived) {
      bgColor = const Color(0xFFECFDF5); // Emerald 50
      textColor = const Color(0xFF065F46); // Emerald 800
      dotColor = const Color(0xFF10B981);
    } else if (isCancelled || letter.stage == 'revoking') {
      bgColor = const Color(0xFFFEE2E2); // Red 100
      textColor = const Color(0xFF991B1B);
      dotColor = const Color(0xFFEF4444);
    } else if (letter.stage == 'received' || letter.stage == 'publishing') {
      bgColor = const Color(0xFFEFF6FF); // Blue 50
      textColor = const Color(0xFF1E40AF);
      dotColor = const Color(0xFF3B82F6);
    } else if (letter.stage == 'reviewing') {
      bgColor = const Color(0xFFFAF5FF); // Purple 50
      textColor = const Color(0xFF6B21A8);
      dotColor = const Color(0xFFA855F7);
    } else if (letter.stage == 'drafting' || letter.stage == 'checking') {
      bgColor = const Color(0xFFF1F5F9); // Slate 100
      textColor = const Color(0xFF475569);
      dotColor = const Color(0xFF64748B);
    }

    final label = letter.stageLabel.isNotEmpty ? letter.stageLabel : letter.stage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

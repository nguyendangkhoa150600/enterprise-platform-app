import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

/// Top Header Card for Letter Detail: Badges, Subject, Sender, Quick Action Buttons
class LetterDetailHeaderCard extends StatelessWidget {
  final LetterDetail letter;
  final VoidCallback? onReply;
  final VoidCallback? onRemind;
  final VoidCallback? onEdit;

  const LetterDetailHeaderCard({
    super.key,
    required this.letter,
    this.onReply,
    this.onRemind,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = letter.direction == 'incoming';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Direction & Number Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isIncoming ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '● ${isIncoming ? "Công văn đến" : "Công văn đi"} ${letter.displayNo}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isIncoming ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
                  ),
                ),
              ),

              // Stage Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '● ${letter.stageLabel.isNotEmpty ? letter.stageLabel : letter.stage}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),

              // Urgency Badge
              if (letter.urgencyHighlight)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '● ${letter.urgencyName}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Subject Title
          Text(
            letter.subject,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle: Sender Org & Ref
          Text(
            isIncoming
                ? '${letter.senderOrg}${letter.senderRef != null && letter.senderRef!.isNotEmpty ? " · ${letter.senderRef}" : ""}'
                : '${letter.authorUnitName ?? letter.senderOrg} → ${letter.recipient ?? ""}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Action Buttons: Soạn trả lời, Đôn đốc, Sửa thông tin
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (letter.actions.reply && onReply != null) ...[
                  OutlinedButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply_rounded, size: 15, color: Color(0xFF334155)),
                    label: const Text(
                      'Soạn trả lời',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (letter.actions.remind && onRemind != null) ...[
                  OutlinedButton.icon(
                    onPressed: onRemind,
                    icon: const Icon(Icons.notifications_active_outlined, size: 15, color: Color(0xFF334155)),
                    label: const Text(
                      'Đôn đốc',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (letter.actions.edit && onEdit != null) ...[
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF334155)),
                    label: const Text(
                      'Sửa thông tin',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
}

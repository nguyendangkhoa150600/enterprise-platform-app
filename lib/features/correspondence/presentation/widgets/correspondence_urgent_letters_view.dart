import 'package:flutter/material.dart';
import '../../domain/models/correspondence_models.dart';
import 'correspondence_letter_detail_bottom_sheet.dart';

class CorrespondenceUrgentLettersView extends StatelessWidget {
  final List<LetterSummary> letters;
  final String today;

  const CorrespondenceUrgentLettersView({
    super.key,
    required this.letters,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Cần xử lý gấp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Letter Items or Empty State
          if (letters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Text(
                  'Không còn công văn nào đang mở.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: letters.length,
              separatorBuilder: (_, index) => const Divider(
                height: 1,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final letter = letters[index];
                return _buildLetterItem(context, letter);
              },
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Hiển thị ${letters.length} công văn',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLetterItem(BuildContext context, LetterSummary letter) {
    final isIncoming = letter.direction == 'incoming';
    final dateStr = CorrespondenceDateUtils.formatDay(
      !isIncoming && letter.publishedOn != null && letter.publishedOn!.isNotEmpty
          ? letter.publishedOn
          : letter.receivedOn,
    );
    final due = CorrespondenceDateUtils.dueText(letter.dueOn, letter.stage, today);
    final partyText = isIncoming
        ? (letter.senderRef != null && letter.senderRef!.isNotEmpty
            ? '${letter.senderOrg} · ${letter.senderRef}'
            : letter.senderOrg)
        : '${letter.authorUnitName ?? letter.authorName ?? ""} → ${letter.recipient ?? ""}';

    return InkWell(
      onTap: () {
        CorrespondenceLetterDetailBottomSheet.show(context, letter, today);
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Số hiệu, Chiều văn bản (Đến/Đi), Ngày vào sổ & Độ khẩn chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        letter.displayNo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isIncoming ? 'Đến' : 'Đi'} · $dateStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildUrgencyChip(letter),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Trích yếu (Tiêu đề công văn)
            Text(
              letter.subject,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),

            // Row 3: Cơ quan ban hành / Gửi đến
            if (partyText.isNotEmpty)
              Text(
                partyText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            const SizedBox(height: 10),

            // Row 4: Bước xử lý & Hạn xử lý
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bước xử lý
                Expanded(
                  child: Row(
                    children: [
                      _buildStageChip(letter),
                      if (letter.currentAssigneeNames.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            letter.currentAssigneeNames.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Hạn xử lý
                if (due != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: due.bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: due.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          due.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: due.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (letter.dueOn != null && letter.dueOn!.isNotEmpty)
                  Text(
                    CorrespondenceDateUtils.formatDay(letter.dueOn),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(LetterSummary letter) {
    final isHighlight = letter.urgencyHighlight;
    final color = isHighlight ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final bgColor = isHighlight ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            letter.urgencyName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip(LetterSummary letter) {
    Color textColor = const Color(0xFF2563EB);
    Color bgColor = const Color(0xFFEFF6FF);

    if (letter.stage == 'reviewing') {
      textColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFEF3C7);
    } else if (letter.stage == 'archived') {
      textColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFFF0FDF4);
    }

    final label = letter.stageLabel.isNotEmpty
        ? letter.stageLabel
        : CorrespondenceConstants.stageLabelOf(letter.stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

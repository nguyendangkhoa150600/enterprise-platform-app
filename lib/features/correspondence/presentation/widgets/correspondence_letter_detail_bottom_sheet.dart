import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/correspondence_models.dart';
import '../screens/correspondence_letter_detail_screen.dart';

class CorrespondenceLetterDetailBottomSheet extends StatelessWidget {
  final LetterSummary letter;
  final String today;

  const CorrespondenceLetterDetailBottomSheet({
    super.key,
    required this.letter,
    required this.today,
  });

  static Future<void> show(BuildContext context, LetterSummary letter, String today) {
    return CorrespondenceLetterDetailScreen.open(context, letter.id);
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = letter.direction == 'incoming';
    final dateStr = CorrespondenceDateUtils.formatDay(
      !isIncoming && letter.publishedOn != null && letter.publishedOn!.isNotEmpty
          ? letter.publishedOn
          : letter.receivedOn,
    );
    final due = CorrespondenceDateUtils.dueText(letter.dueOn, letter.stage, today);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isIncoming ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isIncoming ? 'correspondence.list.incoming'.tr() : 'correspondence.list.outgoing'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isIncoming ? const Color(0xFF2563EB) : const Color(0xFF059669),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            letter.displayNo,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'correspondence.sheet.entry_date'.tr(args: {'date': dateStr}),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trích yếu
                  Text(
                    'correspondence.sheet.subject'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    letter.subject,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid of properties
                  _buildPropertyRow(
                    isIncoming ? 'correspondence.sheet.sender_org'.tr() : 'correspondence.sheet.author_unit'.tr(),
                    letter.senderOrg.isNotEmpty ? letter.senderOrg : (letter.authorUnitName ?? 'correspondence.sheet.not_updated'.tr()),
                  ),
                  if (letter.senderRef != null && letter.senderRef!.isNotEmpty)
                    _buildPropertyRow('correspondence.sheet.original_ref'.tr(), letter.senderRef!),
                  if (letter.kindName.isNotEmpty)
                    _buildPropertyRow('correspondence.sheet.kind'.tr(), letter.kindName),
                  _buildPropertyRow('correspondence.sheet.urgency'.tr(), letter.urgencyName),
                  _buildPropertyRow(
                    'correspondence.sheet.current_step'.tr(),
                    letter.stageLabel.isNotEmpty
                        ? letter.stageLabel
                        : CorrespondenceConstants.stageLabelOf(letter.stage),
                  ),
                  if (letter.currentAssigneeNames.isNotEmpty)
                    _buildPropertyRow('correspondence.sheet.assignees'.tr(), letter.currentAssigneeNames.join(', ')),
                  if (letter.dueOn != null && letter.dueOn!.isNotEmpty)
                    _buildPropertyRow(
                      'correspondence.sheet.due_date'.tr(),
                      '${CorrespondenceDateUtils.formatDay(letter.dueOn)} ${due != null ? "(${due.text})" : ""}',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

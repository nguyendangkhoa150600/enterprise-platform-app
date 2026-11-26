import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Section 3: Metadata Grid matching Savina Web 1:1
class LetterMetadataGridView extends StatelessWidget {
  final LetterDetail letter;
  final String today;

  const LetterMetadataGridView({
    super.key,
    required this.letter,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = letter.direction == 'incoming';
    final due = CorrespondenceDateUtils.dueText(letter.dueOn, letter.stage, today);

    // Tiếp nhận sơ bộ
    final intakeInfo = [
      if (letter.envelopeStatus != null) _envelopeLabel(letter.envelopeStatus!),
      if (letter.sealed) 'correspondence.detail_view.meta_sealed'.tr(),
      if (letter.pageCount != null) 'correspondence.detail_view.meta_pages'.tr(args: {'count': letter.pageCount}),
      if (letter.copyCount != null) 'correspondence.detail_view.meta_copies'.tr(args: {'count': letter.copyCount}),
    ].join(' · ');

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
          // Row 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMetaItem(
                  isIncoming ? 'correspondence.detail_view.meta_received_on'.tr() : 'correspondence.detail_view.meta_sender'.tr(),
                  isIncoming
                      ? CorrespondenceDateUtils.formatDay(letter.receivedOn)
                      : (letter.authorUnitName ?? letter.senderOrg),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  isIncoming ? 'correspondence.detail_view.meta_document_date'.tr() : 'correspondence.detail_view.meta_recipient'.tr(),
                  isIncoming
                      ? (CorrespondenceDateUtils.formatDay(letter.senderDate).isNotEmpty
                          ? CorrespondenceDateUtils.formatDay(letter.senderDate)
                          : 'correspondence.detail_view.meta_not_stated'.tr())
                      : (letter.recipient ?? 'correspondence.detail_view.meta_not_recorded'.tr()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMetaItem(
                  isIncoming ? 'correspondence.detail_view.meta_due_date'.tr() : 'correspondence.detail_view.meta_issue_deadline'.tr(),
                  CorrespondenceDateUtils.formatDay(letter.dueOn).isNotEmpty
                      ? CorrespondenceDateUtils.formatDay(letter.dueOn)
                      : 'correspondence.detail_view.meta_not_set'.tr(),
                  subtext: due?.text,
                  subtextColor: due?.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  'correspondence.detail_view.meta_kind'.tr(),
                  letter.kindName.isNotEmpty ? letter.kindName : 'correspondence.detail_view.meta_unclassified'.tr(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMetaItem(
                  'correspondence.detail_view.meta_urgency_confidentiality'.tr(),
                  '${letter.urgencyName} · ${letter.confidentialityName}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  isIncoming ? 'correspondence.detail_view.meta_received_by'.tr() : 'correspondence.detail_view.meta_draft_no'.tr(),
                  isIncoming ? (letter.receivedByName ?? 'correspondence.detail_view.meta_clerk'.tr()) : letter.incomingNo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 4
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMetaItem(
                  'correspondence.detail_view.meta_register'.tr(),
                  letter.registerName != null && letter.registerName!.isNotEmpty
                      ? letter.registerName!
                      : (isIncoming ? 'correspondence.detail_view.meta_register_incoming'.tr() : 'correspondence.detail_view.meta_register_outgoing'.tr()),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  'correspondence.detail_view.meta_preliminary_intake'.tr(),
                  intakeInfo.isNotEmpty ? intakeInfo : 'correspondence.detail_view.envelope_intact'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(
    String label,
    String value, {
    String? subtext,
    Color? subtextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        if (subtext != null && subtext.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subtextColor ?? const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  String _envelopeLabel(String status) {
    switch (status) {
      case 'intact':
        return 'correspondence.detail_view.envelope_intact'.tr();
      case 'damaged':
        return 'correspondence.detail_view.envelope_damaged'.tr();
      case 'electronic':
        return 'correspondence.detail_view.envelope_electronic'.tr();
      default:
        return status;
    }
  }
}

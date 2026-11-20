import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

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
      if (letter.sealed) 'Niêm phong còn nguyên',
      if (letter.pageCount != null) '${letter.pageCount} tờ',
      if (letter.copyCount != null) '${letter.copyCount} bản',
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
                  isIncoming ? 'Ngày đến' : 'Người gửi',
                  isIncoming
                      ? CorrespondenceDateUtils.formatDay(letter.receivedOn)
                      : (letter.authorUnitName ?? letter.senderOrg),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  isIncoming ? 'Ngày văn bản' : 'Nơi nhận',
                  isIncoming
                      ? (CorrespondenceDateUtils.formatDay(letter.senderDate).isNotEmpty
                          ? CorrespondenceDateUtils.formatDay(letter.senderDate)
                          : 'Không ghi')
                      : (letter.recipient ?? 'Chưa ghi'),
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
                  isIncoming ? 'Hạn xử lý' : 'Hạn ban hành',
                  CorrespondenceDateUtils.formatDay(letter.dueOn).isNotEmpty
                      ? CorrespondenceDateUtils.formatDay(letter.dueOn)
                      : 'Không đặt',
                  subtext: due?.text,
                  subtextColor: due?.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  'Loại văn bản',
                  letter.kindName.isNotEmpty ? letter.kindName : 'Chưa phân loại',
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
                  'Độ khẩn · Độ mật',
                  '${letter.urgencyName} · ${letter.confidentialityName}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  isIncoming ? 'Văn thư tiếp nhận' : 'Số dự thảo',
                  isIncoming ? (letter.receivedByName ?? 'Văn thư') : letter.incomingNo,
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
                  'Sổ đăng ký',
                  letter.registerName != null && letter.registerName!.isNotEmpty
                      ? letter.registerName!
                      : (isIncoming ? 'Sổ công văn đến' : 'Sổ công văn đi'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetaItem(
                  'Tiếp nhận sơ bộ',
                  intakeInfo.isNotEmpty ? intakeInfo : 'Bì nguyên vẹn',
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
        return 'Bì nguyên vẹn';
      case 'damaged':
        return 'Bì rách, có dấu hiệu bóc mở';
      case 'electronic':
        return 'Văn bản điện tử';
      default:
        return status;
    }
  }
}

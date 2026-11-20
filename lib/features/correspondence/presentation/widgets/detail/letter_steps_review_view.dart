import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

/// Section 4: Ý kiến các bước duyệt matching Savina Web 1:1
class LetterStepsReviewView extends StatelessWidget {
  final List<LetterStep> steps;

  const LetterStepsReviewView({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

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
          const Text(
            'Ý kiến các bước duyệt',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final step = steps[index];
              return _buildStepItem(step);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(LetterStep step) {
    final returned = step.decision == 'returned' && step.status != 'done';
    String statusLabel = 'Chưa tới';
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = const Color(0xFF64748B);
    Color dotColor = const Color(0xFF94A3B8);

    if (returned) {
      statusLabel = 'Không đạt';
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      dotColor = const Color(0xFFEF4444);
    } else if (step.status == 'done') {
      statusLabel = 'Đạt';
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF059669);
      dotColor = const Color(0xFF10B981);
    } else if (step.status == 'active') {
      statusLabel = 'Đang chờ duyệt';
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
      dotColor = const Color(0xFFF59E0B);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${step.seq}. ${step.name}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (step.assignees.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Người duyệt: ${step.assignees.join(", ")}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
              if (step.actedAt != null && step.actedAt!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '${returned ? "Trả lại" : "Đạt"} · ${step.actedByName ?? "Người dùng"} lúc ${CorrespondenceDateUtils.formatDateTime(step.actedAt)}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
              ],
              if (step.note != null && step.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    step.note!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(
                statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

/// Section 7: Lịch sử xử lý (History / Audit Timeline) matching Savina Web 1:1
class LetterHistoryTimelineView extends StatelessWidget {
  final List<LetterHistoryEntry> history;

  const LetterHistoryTimelineView({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    // Reverse history to show newest first like Web
    final items = history.reversed.toList();

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
            'Lịch sử xử lý',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Timeline items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];
              final isLast = index == items.length - 1;
              return _buildTimelineItem(entry, isLast);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(LetterHistoryEntry entry, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot & Connector Line
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB), // Blue dot
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFFCBD5E1),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.summary,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.actorName ?? "Người dùng"} lúc ${CorrespondenceDateUtils.formatDateTime(entry.at)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.note!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

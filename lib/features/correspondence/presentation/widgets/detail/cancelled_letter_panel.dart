import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// Panel "Công văn đã huỷ" đồng bộ 1:1 với Savina Web CancelledPanel
class CancelledLetterPanel extends StatefulWidget {
  final LetterDetail letter;
  final Future<void> Function()? onRemoveLetter;

  const CancelledLetterPanel({
    super.key,
    required this.letter,
    this.onRemoveLetter,
  });

  @override
  State<CancelledLetterPanel> createState() => _CancelledLetterPanelState();
}

class _CancelledLetterPanelState extends State<CancelledLetterPanel> {
  bool _isRemoving = false;

  Future<void> _handleRemove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('correspondence.panel.cancelled.delete_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'correspondence.panel.cancelled.delete_message'.tr(),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('correspondence.panel.cancelled.keep'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('correspondence.panel.cancelled.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && widget.onRemoveLetter != null) {
      setState(() => _isRemoving = true);
      try {
        await widget.onRemoveLetter!();
      } finally {
        if (mounted) setState(() => _isRemoving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final revoke = letter.revoke;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'correspondence.panel.cancelled.title'.tr(),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (revoke != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('correspondence.revoke.kind_label'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      Text(revoke.kindLabel, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'correspondence.revoke.requested_by'.tr(args: {'name': revoke.requestedByName ?? 'correspondence.revoke.default_requester'.tr(), 'time': revoke.requestedAt != null ? ' · ${CorrespondenceDateUtils.formatDateTime(revoke.requestedAt)}' : ''}),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'correspondence.panel.reason_inline'.tr(args: {'reason': revoke.reason}),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'correspondence.panel.reason_inline'.tr(args: {'reason': letter.cancelReason ?? 'correspondence.panel.cancelled.default_reason'.tr()}),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
          if (letter.actions.remove && widget.onRemoveLetter != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isRemoving ? null : _handleRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                label: Text('correspondence.panel.cancelled.delete_button'.tr(), style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFCA5A5))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

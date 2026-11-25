import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// Panel "Đề nghị huỷ công văn" đồng bộ 1:1 với Savina Web RevokingPanel
class RevokingLetterPanel extends StatefulWidget {
  final LetterDetail letter;
  final Future<void> Function(bool approve, String? note) onDecideRevoke;
  final Future<void> Function() onWithdrawRevoke;

  const RevokingLetterPanel({
    super.key,
    required this.letter,
    required this.onDecideRevoke,
    required this.onWithdrawRevoke,
  });

  @override
  State<RevokingLetterPanel> createState() => _RevokingLetterPanelState();
}

class _RevokingLetterPanelState extends State<RevokingLetterPanel> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleDecide(bool approve) async {
    final title = approve ? 'correspondence.revoke.confirm_approve_title'.tr() : 'correspondence.revoke.confirm_reject_title'.tr();
    final desc = approve
        ? 'correspondence.revoke.confirm_approve_message'.tr(args: {'no': widget.letter.displayNo})
        : 'correspondence.revoke.confirm_reject_message'.tr();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('correspondence.revoke.review'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'correspondence.revoke.approve'.tr() : 'correspondence.revoke.reject'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSubmitting = true);
      try {
        await widget.onDecideRevoke(approve, _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleWithdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('correspondence.revoke.withdraw_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'correspondence.revoke.withdraw_message'.tr(),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('correspondence.revoke.review'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('correspondence.revoke.withdraw'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSubmitting = true);
      try {
        await widget.onWithdrawRevoke();
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final revoke = widget.letter.revoke;
    final actions = widget.letter.actions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
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
            'correspondence.revoke.title'.tr(),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 12),
          if (revoke != null) ...[
            _buildRevokeSummary(revoke),
            const SizedBox(height: 14),
          ],
          if (actions.decideRevoke) ...[
            Text(
              'correspondence.revoke.decision_note_label'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'correspondence.revoke.decision_note_hint'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _handleDecide(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: Text('correspondence.revoke.reject'.tr(), style: const TextStyle(color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _handleDecide(true),
                    icon: const Icon(Icons.block_outlined, size: 16),
                    label: Text('correspondence.revoke.approve'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'correspondence.revoke.pending_note'.tr(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            if (actions.withdrawRevoke) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _handleWithdraw,
                  icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text('correspondence.revoke.withdraw'.tr(), style: const TextStyle(color: Color(0xFFD97706), fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B))),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRevokeSummary(LetterRevoke revoke) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('correspondence.revoke.kind_label'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
              Text(revoke.kindLabel, style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'correspondence.revoke.requested_by'.tr(args: {'name': revoke.requestedByName ?? 'correspondence.revoke.default_requester'.tr(), 'time': revoke.requestedAt != null ? ' · ${CorrespondenceDateUtils.formatDateTime(revoke.requestedAt)}' : ''}),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 4),
          Text(
            'correspondence.panel.reason_inline'.tr(args: {'reason': revoke.reason}),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
          ),
          if (revoke.approverNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'correspondence.revoke.approvers'.tr(args: {'names': revoke.approverNames.join(", ")}),
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

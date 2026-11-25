import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';
import 'cancel_letter_dialog.dart';
import 'letter_action_buttons.dart';
import 'workflow_preview_view.dart';

/// Panel "Phòng ban soạn thảo: gửi 'Văn thư kiểm tra'" đồng bộ 1:1 với Web SendToClerkForm
class SendToClerkPanel extends StatefulWidget {
  final LetterDetail letter;
  final CorrespondenceConfig config;
  final CorrespondenceDirectory directory;
  final Future<void> Function(Map<String, dynamic> body) onSendToClerk;
  final Future<void> Function(String reason) onCancel;

  const SendToClerkPanel({
    super.key,
    required this.letter,
    required this.config,
    required this.directory,
    required this.onSendToClerk,
    required this.onCancel,
  });

  @override
  State<SendToClerkPanel> createState() => _SendToClerkPanelState();
}

class _SendToClerkPanelState extends State<SendToClerkPanel> {
  final TextEditingController _noteController = TextEditingController();
  late String _workflowId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _workflowId = widget.letter.chosenWorkflowId ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleCancel() async {
    final reason = await CancelLetterDialog.show(context, displayNo: widget.letter.displayNo);
    if (reason != null && reason.isNotEmpty) {
      setState(() => _isSubmitting = true);
      try {
        await widget.onCancel(reason);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleSubmit(String target) async {
    setState(() => _isSubmitting = true);
    try {
      await widget.onSendToClerk({
        'note': _noteController.text.trim(),
        if (_workflowId.isNotEmpty) 'workflowId': _workflowId,
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = widget.letter.attachments.where((item) => item.kind == 'draft').length;
    final nextNode = widget.letter.flow.length > 1 ? widget.letter.flow[1] : null;
    final target = nextNode?.label ?? 'correspondence.panel.clerk_check_step'.tr();
    final firstLabel = widget.letter.flow.isNotEmpty ? widget.letter.flow[0].label : 'correspondence.workflow.start_outgoing'.tr();
    final panelTitle = 'correspondence.panel.send_to_clerk.title'.tr(args: {'first': firstLabel, 'target': target});

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
            panelTitle,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            drafts > 0 ? 'correspondence.panel.send_to_clerk.drafts_count'.tr(args: {'count': drafts}) : 'correspondence.panel.send_to_clerk.drafts_missing'.tr(),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          WorkflowPreviewView(
            config: widget.config,
            direction: widget.letter.direction,
            kind: widget.letter.kind,
            selectedWorkflowId: _workflowId,
            directory: widget.directory,
            onWorkflowChanged: (val) => setState(() => _workflowId = val),
          ),
          const SizedBox(height: 14),
          Text(
            'common.note'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'correspondence.panel.send_to_clerk.note_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          LetterActionButtons(
            cancelButton: widget.letter.actions.cancel
                ? OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleCancel,
                    icon: const Icon(Icons.block_outlined, size: 15, color: Color(0xFFDC2626)),
                    label: Text(
                      'correspondence.panel.cancel_letter'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : null,
            primaryButton: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _handleSubmit(target),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('correspondence.panel.send_to_clerk.submit'.tr(args: {'target': target}), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

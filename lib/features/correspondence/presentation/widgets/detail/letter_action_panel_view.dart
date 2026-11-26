import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';
import 'approve_letter_panel.dart';
import 'archived_letter_panel.dart';
import 'cancel_letter_dialog.dart';
import 'cancelled_letter_panel.dart';
import 'dispatch_letter_panel.dart';
import 'letter_action_buttons.dart';
import 'publish_letter_panel.dart';
import 'revoking_letter_panel.dart';
import 'send_to_clerk_panel.dart';
import '../dialogs/return_letter_dialog.dart';

/// Bộ điều phối hiển thị ô thao tác cho bước hiện tại đồng bộ 1:1 với Savina Web LetterActionPanel
class LetterActionPanelView extends StatefulWidget {
  final LetterDetail letter;
  final CorrespondenceConfig config;
  final CorrespondenceDirectory directory;
  final Future<void> Function(Map<String, dynamic> body) onDispatch;
  final Future<void> Function(Map<String, dynamic> body) onApprove;
  final Future<void> Function(Map<String, dynamic> body) onReturn;
  final Future<void> Function(Map<String, dynamic> body) onSendToClerk;
  final Future<void> Function(Map<String, dynamic> body) onSubmit;
  final Future<void> Function(Map<String, dynamic> body) onPublish;
  final Future<void> Function(Map<String, dynamic> body) onComplete;
  final Future<void> Function(String reason) onCancel;
  final Future<void> Function(Map<String, dynamic> body) onUpdateDelivery;
  final Future<void> Function(Map<String, dynamic> body) onRequestRevoke;
  final Future<void> Function(bool approve, String? note)? onDecideRevoke;
  final Future<void> Function()? onWithdrawRevoke;
  final Future<void> Function()? onRemoveLetter;

  const LetterActionPanelView({
    super.key,
    required this.letter,
    required this.config,
    required this.directory,
    required this.onDispatch,
    required this.onApprove,
    required this.onReturn,
    required this.onSendToClerk,
    required this.onSubmit,
    required this.onPublish,
    required this.onComplete,
    required this.onCancel,
    required this.onUpdateDelivery,
    required this.onRequestRevoke,
    this.onDecideRevoke,
    this.onWithdrawRevoke,
    this.onRemoveLetter,
  });

  @override
  State<LetterActionPanelView> createState() => _LetterActionPanelViewState();
}

class _LetterActionPanelViewState extends State<LetterActionPanelView> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  /// Đổi khi công văn sang bước mới: buộc các panel con tạo lại state
  /// (đơn vị, hạn, ghi chú) thay vì giữ dữ liệu của bước trước.
  String _stepKeyOf(LetterDetail l) =>
      '${l.id}|${l.stage}|${l.currentStepName ?? ''}|${l.steps.length}';

  @override
  void didUpdateWidget(covariant LetterActionPanelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stepKeyOf(oldWidget.letter) != _stepKeyOf(widget.letter)) {
      _noteController.clear();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleReturn() async {
    // Nơi trả về, bước, phòng ban làm lại và lý do: chọn trong hộp thoại dùng chung (như web).
    final body = await ReturnLetterDialog.show(context, widget.letter);
    if (body == null || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onReturn(body);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  Widget _buildCardContainer({required String title, required List<Widget> children, Color? titleColor}) {
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
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: titleColor ?? const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.letter.actions;
    final panelKey = ValueKey(_stepKeyOf(widget.letter));

    if (widget.letter.stage == 'archived') {
      return ArchivedLetterPanel(
        key: panelKey,
        letter: widget.letter,
        onUpdateDelivery: widget.onUpdateDelivery,
        onRequestRevoke: widget.onRequestRevoke,
      );
    }

    if (widget.letter.stage == 'revoking') {
      return RevokingLetterPanel(
        key: panelKey,
        letter: widget.letter,
        onDecideRevoke: widget.onDecideRevoke ?? (approve, note) async {},
        onWithdrawRevoke: widget.onWithdrawRevoke ?? () async {},
      );
    }

    if (widget.letter.stage == 'cancelled') {
      return CancelledLetterPanel(
        key: panelKey,
        letter: widget.letter,
        onRemoveLetter: widget.onRemoveLetter,
      );
    }

    // 1. Soạn thảo công văn đi: Gửi văn thư kiểm tra
    if (actions.sendToClerk) {
      return SendToClerkPanel(
        key: panelKey,
        letter: widget.letter,
        config: widget.config,
        directory: widget.directory,
        onSendToClerk: widget.onSendToClerk,
        onCancel: widget.onCancel,
      );
    }

    // 2. Văn thư giao phòng ban (Công văn đến)
    if (actions.dispatch) {
      return DispatchLetterPanel(
        key: panelKey,
        letter: widget.letter,
        directory: widget.directory,
        onDispatch: widget.onDispatch,
        onReturn: widget.onReturn,
        onCancel: widget.onCancel,
      );
    }

    // 3. Văn thư kiểm tra / Chuyển bước kế tiếp (Submit)
    if (actions.submit) {
      return _buildSubmitPanel();
    }

    // 4. Lãnh đạo phê duyệt / Giao phòng ban (Approve)
    if (actions.approve) {
      return ApproveLetterPanel(
        key: panelKey,
        letter: widget.letter,
        config: widget.config,
        directory: widget.directory,
        onApprove: widget.onApprove,
        onReturn: widget.onReturn,
        onCancel: widget.onCancel,
      );
    }

    // 5. Hoàn tất & lưu trữ (Complete)
    if (actions.complete) {
      return _buildCompletePanel();
    }

    // 6. Ban hành công văn đi (Publish)
    if (actions.publish) {
      return PublishLetterPanel(
        key: panelKey,
        letter: widget.letter,
        config: widget.config,
        directory: widget.directory,
        onPublish: widget.onPublish,
        onReturn: widget.onReturn,
      );
    }

    // 7. Chờ người khác xử lý (Waiting Note)
    return _buildWaitingNotePanel();
  }

  /// 3. Submit Panel (Văn thư kiểm tra)
  Widget _buildSubmitPanel() {
    final curIdx = widget.letter.flow.indexWhere((n) => n.state == 'current');
    final nextNode = curIdx >= 0 && curIdx + 1 < widget.letter.flow.length ? widget.letter.flow[curIdx + 1] : null;
    final nextName = nextNode?.label ?? widget.letter.flow.lastOrNull?.label ?? 'correspondence.panel.next_step_fallback'.tr();

    return _buildCardContainer(
      title: widget.letter.currentStepName ?? 'correspondence.panel.clerk_check_step'.tr(),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
          child: Row(
            children: [
              Text('correspondence.panel.next_step_label'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              Text(nextName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('common.note'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: _noteController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'correspondence.panel.check_note_hint'.tr(),
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
                  label: Text('correspondence.panel.cancel_letter'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFCA5A5)), backgroundColor: Colors.white),
                )
              : null,
          returnButton: widget.letter.actions.returnTargets.isNotEmpty
              ? OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _handleReturn,
                  icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text('correspondence.panel.return'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B)), backgroundColor: Colors.white),
                )
              : null,
          primaryButton: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    try {
                      await widget.onSubmit({'note': _noteController.text.trim()});
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    'correspondence.panel.pass_forward'.tr(args: {'name': nextName}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  /// 5. Complete Panel (Hoàn tất & lưu trữ)
  Widget _buildCompletePanel() {
    final title = widget.letter.flow.isNotEmpty ? widget.letter.flow.last.label : 'correspondence.workflow.end_incoming'.tr();
    return _buildCardContainer(
      title: title,
      children: [
        Text('correspondence.panel.close_note_label'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: _noteController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'correspondence.panel.note_hint_short'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),
        LetterActionButtons(
          returnButton: widget.letter.actions.returnTargets.isNotEmpty
              ? OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _handleReturn,
                  icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text('correspondence.panel.return'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B)), backgroundColor: Colors.white),
                )
              : null,
          primaryButton: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    try {
                      await widget.onComplete({'note': _noteController.text.trim()});
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('correspondence.panel.complete_archive'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  /// 7. Waiting Note Panel
  Widget _buildWaitingNotePanel() {
    final pending = widget.letter.assignments.where((a) => a.status == 'pending').toList();
    final who = widget.letter.currentAssigneeNames.isNotEmpty
        ? widget.letter.currentAssigneeNames.join(', ')
        : 'correspondence.panel.assignee_fallback'.tr();

    String noteText = '';
    switch (widget.letter.stage) {
      case 'received':
        noteText = 'correspondence.panel.waiting.received'.tr();
        break;
      case 'processing':
        noteText = pending.isNotEmpty
            ? 'correspondence.panel.waiting.processing'.tr(args: {'units': pending.map((p) => p.handlerName != null ? "${p.unitName} (${p.handlerName})" : p.unitName).join(", ")})
            : 'correspondence.panel.waiting.processing_done'.tr();
        break;
      case 'drafting':
        noteText = 'correspondence.panel.waiting.drafting'.tr(args: {'name': widget.letter.authorName ?? 'correspondence.panel.author_fallback'.tr()});
        break;
      case 'checking':
        noteText = 'correspondence.panel.waiting.checking'.tr(args: {'step': widget.letter.currentStepName ?? 'correspondence.panel.clerk_check_step'.tr()});
        break;
      case 'reviewing':
        noteText = 'correspondence.panel.waiting.reviewing'.tr(args: {'step': widget.letter.currentStepName ?? '', 'who': who});
        break;
      case 'closing':
        noteText = 'correspondence.panel.waiting.closing'.tr();
        break;
      case 'publishing':
        noteText = 'correspondence.panel.waiting.publishing'.tr();
        break;
      default:
        noteText = 'correspondence.panel.waiting.default'.tr();
    }

    return _buildCardContainer(
      title: 'correspondence.panel.current_step'.tr(),
      titleColor: const Color(0xFF64748B),
      children: [
        Text(noteText, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
        if (widget.letter.actions.cancel || widget.letter.actions.returnTargets.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (widget.letter.actions.cancel)
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _handleCancel,
                  icon: const Icon(Icons.block_outlined, size: 15, color: Color(0xFFDC2626)),
                  label: Text('correspondence.panel.cancel_letter'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFCA5A5)), backgroundColor: Colors.white),
                ),
              if (widget.letter.actions.returnTargets.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _handleReturn,
                  icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text('correspondence.panel.return_to_clerk'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B)), backgroundColor: Colors.white),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

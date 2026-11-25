import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/workspace_models.dart';

/// Server giới hạn độ dài lý do vướng mắc (contracts `BLOCKED_REASON_MAX_LENGTH`).
const int _blockedReasonMaxLength = 1000;

/// Hộp "Báo vướng mắc" — đồng bộ web `blocked-reason-dialog.tsx`.
///
/// Lý do bắt buộc vì server từ chối `status: 'blocked'` không kèm `note`.
/// [onSubmit] gửi lý do; trả `null` khi thành công, hoặc thông báo lỗi để hộp
/// hiện ra và ở lại cho người dùng gửi lại. Trả `true` khi đã ghi thành công.
Future<bool> showWorkspaceBlockedReasonDialog(
  BuildContext context, {
  required StandaloneTaskItem task,
  required Future<String?> Function(String reason) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BlockedReasonDialog(task: task, onSubmit: onSubmit),
  );
  return result ?? false;
}

class _BlockedReasonDialog extends StatefulWidget {
  final StandaloneTaskItem task;
  final Future<String?> Function(String reason) onSubmit;

  const _BlockedReasonDialog({required this.task, required this.onSubmit});

  @override
  State<_BlockedReasonDialog> createState() => _BlockedReasonDialogState();
}

class _BlockedReasonDialogState extends State<_BlockedReasonDialog> {
  late final TextEditingController _ctrl;
  bool _submitting = false;
  String? _error;

  bool get _editing => (widget.task.blockedReason ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.task.blockedReason ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSubmit(reason);
    } catch (_) {
      error = 'workspace.kanban.blocked_failed'.tr();
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _ctrl.text.trim().isNotEmpty && !_submitting;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editing ? 'workspace.kanban.blocked_edit_title'.tr() : 'workspace.kanban.blocked_title'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          Text(
            '${widget.task.code} · ${widget.task.title}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workspace.kanban.blocked_label'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 4,
              maxLines: 6,
              maxLength: _blockedReasonMaxLength,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'workspace.kanban.blocked_placeholder'.tr(),
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('workspace.kanban.blocked_submit'.tr()),
        ),
      ],
    );
  }
}

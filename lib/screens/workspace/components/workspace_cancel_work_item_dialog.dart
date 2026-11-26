import 'package:flutter/material.dart';
import '../../../services/workspace_service.dart';
import '../../../core/i18n/app_i18n.dart';

/// Hộp thoại xác nhận huỷ công việc kèm lý do huỷ, đồng bộ 1:1 với Web React
Future<bool> showCancelWorkItemDialog(
  BuildContext context, {
  required String workItemId,
  String? workItemCode,
  required String workItemTitle,
  required WorkspaceService service,
  /// Việc trong dự án dùng API work-item, việc lẻ dùng API standalone — không gọi chéo.
  bool isProjectTask = true,
  /// Số việc con còn mở trong nhánh (web `openChildren`).
  int openChildren = 0,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CancelWorkItemDialog(
      workItemId: workItemId,
      workItemCode: workItemCode,
      workItemTitle: workItemTitle,
      service: service,
      isProjectTask: isProjectTask,
      openChildren: openChildren,
    ),
  );
  return result ?? false;
}

class _CancelWorkItemDialog extends StatefulWidget {
  final String workItemId;
  final String? workItemCode;
  final String workItemTitle;
  final WorkspaceService service;
  final bool isProjectTask;
  final int openChildren;

  const _CancelWorkItemDialog({
    required this.workItemId,
    this.workItemCode,
    required this.workItemTitle,
    required this.service,
    required this.isProjectTask,
    required this.openChildren,
  });

  @override
  State<_CancelWorkItemDialog> createState() => _CancelWorkItemDialogState();
}

class _CancelWorkItemDialogState extends State<_CancelWorkItemDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmCancel() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final note = _reasonController.text.trim();
    final ok = widget.isProjectTask
        ? await widget.service.updateWorkItemStatus(
            widget.workItemId,
            'cancelled',
            note: note.isNotEmpty ? note : null,
          )
        : await widget.service.changeStandaloneTaskStatus(
            widget.workItemId,
            'cancelled',
            note: note.isNotEmpty ? note : null,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    // Như web: giữ hộp thoại, hiện lời nhắn của server (vd. còn việc con đang mở).
    setState(() {
      _isSubmitting = false;
      _error = widget.service.lastError ?? 'workspace.cancel_item.failed'.tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final titlePrefix = widget.workItemCode != null && widget.workItemCode!.isNotEmpty
        ? '${widget.workItemCode} · '
        : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề khớp 1:1 Web
              Text(
                'Bạn có chắc chắn muốn huỷ $titlePrefix${widget.workItemTitle}?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Đoạn giải thích
              Text(
                widget.openChildren > 0
                    ? 'workspace.cancel_item.message_with_children'.tr(args: {'count': widget.openChildren})
                    : 'workspace.cancel_item.message'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Nhãn trường lý do
              const Text(
                'Lý do huỷ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              // Ô nhập lý do hủy
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                enabled: !_isSubmitting,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Ghi lý do để người khác hiểu vì sao việc bị huỷ (không bắt buộc)',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
              ],
              const SizedBox(height: 20),

              // Hàng nút hành động căn phải
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      foregroundColor: const Color(0xFF334155),
                    ),
                    child: const Text('Không', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleConfirmCancel,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Huỷ công việc',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

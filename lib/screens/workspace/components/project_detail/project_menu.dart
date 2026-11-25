import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../../models/workspace_models.dart';

/// Lệnh của menu "⋯" dự án (web projects-view.tsx `allActionsFor({kind:'project'})`).
enum ProjectMenuAction { addRootItem, editProject, openChat, refresh, cancelProject }

/// Mở menu dự án. Dự án đã lưu trữ chỉ còn "Mở trao đổi" và "Tải lại".
/// [canEditProject]: mobile chưa có form sửa dự án — tắt mục thay vì mở màn trống.
Future<ProjectMenuAction?> showProjectMenu(
  BuildContext context, {
  required ProjectItem project,
  bool canEditProject = false,
}) {
  final access = project.access;
  final archived = project.isArchived;
  final entries = <(ProjectMenuAction, String, bool, bool, bool)>[
    // (action, label, enabled, danger, separatorBefore)
    if (!archived) (ProjectMenuAction.addRootItem, 'workspace.project_menu.add_root_item'.tr(), access.canWrite, false, false),
    if (!archived)
      (ProjectMenuAction.editProject, 'workspace.project_menu.edit_project'.tr(), access.canManage && canEditProject, false, false),
    (ProjectMenuAction.openChat, 'workspace.project_menu.open_chat'.tr(), true, false, !archived),
    (ProjectMenuAction.refresh, 'workspace.task_detail.menu.refresh'.tr(), true, false, false),
    if (!archived) (ProjectMenuAction.cancelProject, 'workspace.project_menu.cancel_project'.tr(), access.canOwn, true, true),
  ];
  return showModalBottomSheet<ProjectMenuAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final e in entries) ...[
            if (e.$5) const Divider(height: 1),
            ListTile(
              dense: true,
              enabled: e.$3,
              title: Text(
                e.$2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: !e.$3
                      ? const Color(0xFF94A3B8)
                      : e.$4
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF0F172A),
                ),
              ),
              onTap: () => Navigator.pop(ctx, e.$1),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Hộp xác nhận dùng chung cho "Huỷ dự án" và "Mở lưu trữ" (web CancelProjectDialog / Confirm).
/// [onConfirm] trả lời nhắn lỗi (null khi thành công); lỗi hiện ngay trong hộp như web.
Future<bool> showProjectConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required bool danger,
  required Future<String?> Function() onConfirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      danger: danger,
      onConfirm: onConfirm,
    ),
  );
  return ok == true;
}

class _ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;
  final Future<String?> Function() onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.danger,
    required this.onConfirm,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onConfirm();
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: const TextStyle(fontSize: 13.5)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('common.no'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.danger ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

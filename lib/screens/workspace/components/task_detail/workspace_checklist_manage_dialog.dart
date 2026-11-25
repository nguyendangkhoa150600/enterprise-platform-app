import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_checklist_api.dart';
import '../../../../utils/app_toast.dart';
import 'workspace_checklist_access.dart';

/// Khác biệt giữa bản nháp trong hộp "Quản lý checklist" và danh sách đang lưu.
class ChecklistDraftChanges {
  final List<ChecklistEntry> removed;
  /// id → tên mới.
  final Map<String, String> renamed;
  final List<String> added;
  const ChecklistDraftChanges({required this.removed, required this.renamed, required this.added});
}

class _DraftRow {
  final String key;
  final String? id;
  final TextEditingController controller;
  _DraftRow({required this.key, this.id, required String title}) : controller = TextEditingController(text: title);
}

/// Hộp "Quản lý checklist" (web `checklist-panel.tsx`): thêm (Enter / dán nhiều dòng), sửa tên, xoá trên bản nháp;
/// chỉ khi bấm "Cập nhật" mới trả về khác biệt để panel gửi server. Đụng đầu việc đã hoàn thành thì hỏi lại.
class WorkspaceChecklistManageDialog extends StatefulWidget {
  final List<ChecklistEntry> items;

  const WorkspaceChecklistManageDialog({super.key, required this.items});

  static Future<ChecklistDraftChanges?> show(BuildContext context, List<ChecklistEntry> items) =>
      showDialog<ChecklistDraftChanges>(
        context: context,
        builder: (_) => WorkspaceChecklistManageDialog(items: items),
      );

  @override
  State<WorkspaceChecklistManageDialog> createState() => _WorkspaceChecklistManageDialogState();
}

class _WorkspaceChecklistManageDialogState extends State<WorkspaceChecklistManageDialog> {
  final TextEditingController _title = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final List<_DraftRow> _rows = [];
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    for (final entry in widget.items) {
      _rows.add(_DraftRow(key: entry.id, id: entry.id, title: entry.title));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  static String _clip(String text) {
    final trimmed = text.trim();
    return trimmed.length > checklistTitleMaxLength ? trimmed.substring(0, checklistTitleMaxLength) : trimmed;
  }

  void _addDraft(List<String> titles) {
    final list = titles.map(_clip).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return;
    final room = maxChecklistItems - _rows.length;
    if (room <= 0) {
      AppToast.error(context, 'workspace.checklist.max_items'.tr(args: {'max': maxChecklistItems}));
      return;
    }
    if (list.length > room) {
      AppToast.error(context, 'workspace.checklist.max_items_trimmed'.tr(args: {'max': maxChecklistItems}));
    }
    setState(() {
      for (final text in list.take(room)) {
        _rows.add(_DraftRow(key: 'new-${++_seq}', title: text));
      }
      _title.clear();
    });
    _titleFocus.requestFocus();
  }

  /// Ô thêm cho phép nhiều dòng để nhận văn bản dán: có xuống dòng thì tách thành nhiều đầu việc.
  void _onTitleChanged(String value) {
    if (value.contains('\n')) {
      _addDraft(splitChecklistLines(value));
    } else {
      setState(() {});
    }
  }

  ChecklistEntry? _original(String? id) {
    for (final entry in widget.items) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  ChecklistDraftChanges get _changes {
    final removed = widget.items.where((entry) => !_rows.any((row) => row.id == entry.id)).toList();
    final renamed = <String, String>{};
    for (final row in _rows) {
      if (row.id == null) continue;
      final text = _clip(row.controller.text);
      if (text.isNotEmpty && text != _original(row.id)?.title) renamed[row.id!] = text;
    }
    final added = _rows
        .where((row) => row.id == null && row.controller.text.trim().isNotEmpty)
        .map((row) => row.controller.text)
        .toList();
    return ChecklistDraftChanges(removed: removed, renamed: renamed, added: added);
  }

  bool _hasChanges(ChecklistDraftChanges c) => c.removed.isNotEmpty || c.renamed.isNotEmpty || c.added.isNotEmpty;

  Future<void> _submit() async {
    final changes = _changes;
    if (!_hasChanges(changes)) return;
    final removedDone = changes.removed.any((entry) => entry.done);
    final touchesDone = removedDone || changes.renamed.keys.any((id) => _original(id)?.done == true);
    if (touchesDone) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('workspace.checklist.confirm_done_title'.tr()),
          content: Text(
            (removedDone ? 'workspace.checklist.confirm_done_removed' : 'workspace.checklist.confirm_done_renamed').tr(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common.update'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    Navigator.pop(context, changes);
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = _hasChanges(_changes);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'workspace.checklist.manage_title'.tr(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'workspace.checklist.manage_subtitle'.tr(),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: _inputDecoration('workspace.checklist.add_placeholder'.tr()),
                      onChanged: _onTitleChanged,
                      onSubmitted: (_) => _addDraft([_title.text]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _title.text.trim().isEmpty ? null : () => _addDraft([_title.text]),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('common.add'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'workspace.checklist.empty'.tr(),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) => _buildRow(_rows[index]),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: hasChanges ? _submit : null, child: Text('common.update'.tr())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_DraftRow row) {
    return Row(
      key: ValueKey(row.key),
      children: [
        Expanded(
          child: TextField(
            controller: row.controller,
            maxLength: checklistTitleMaxLength,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDecoration(null),
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
          tooltip: 'workspace.checklist.remove_item'.tr(),
          onPressed: () {
            setState(() => _rows.remove(row));
            // Gỡ ô khỏi cây trước rồi mới huỷ controller.
            WidgetsBinding.instance.addPostFrameCallback((_) => row.controller.dispose());
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_reverse_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';

/// Hộp "Huỷ hiệu lực…" như web `reverse-work-item-dialog.tsx`: xác nhận huỷ hiệu lực công việc đã hoàn thành.
///
/// Trả `true` khi thành công và cần mở form công việc điều chỉnh (đã chọn "Lập hồ sơ điều chỉnh" và việc
/// không gắn hồ sơ Quy trình — việc theo quy trình thì người giữ vai S nhận thông báo bên Quy trình, như
/// web `projects-view.tsx`), `false` khi thành công mà không cần mở form, null khi huỷ.
Future<bool?> showReverseWorkItemDialog(
  BuildContext context, {
  required StandaloneTaskItem item,
  required WorkspaceService service,
  required List<StandaloneTaskItem> projectItems,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReverseWorkItemDialog(item: item, projectItems: projectItems),
    );

class _ReverseWorkItemDialog extends StatefulWidget {
  final StandaloneTaskItem item;
  final List<StandaloneTaskItem> projectItems;

  const _ReverseWorkItemDialog({required this.item, required this.projectItems});

  @override
  State<_ReverseWorkItemDialog> createState() => _ReverseWorkItemDialogState();
}

class _ReverseWorkItemDialogState extends State<_ReverseWorkItemDialog> {
  final WorkspaceReverseApi _api = WorkspaceReverseApi();
  final TextEditingController _reason = TextEditingController();
  bool _adjust = true;
  bool _submitting = false;
  String? _error;

  /// Việc đang phụ thuộc (FS) vào việc này, chưa huỷ.
  List<StandaloneTaskItem> _dependents = const [];

  /// Mã hồ sơ Quy trình gắn công việc, nếu có — hồ sơ bị huỷ hiệu lực theo.
  String? _linkedCode;
  bool _linked = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Như web: phụ thuộc và con trỏ sang module khác lấy theo dự án; hỏng thì coi như rỗng.
  Future<void> _loadContext() async {
    final projectId = widget.item.projectId;
    if (projectId == null || projectId.isEmpty) return;
    final results = await Future.wait([
      _api.projectDependencies(projectId),
      _api.projectExternalReferences(projectId),
    ]);
    if (!mounted) return;
    final deps = results[0].data ?? const [];
    final refs = results[1].data ?? const [];
    final id = widget.item.id;
    final dependents = <StandaloneTaskItem>[];
    for (final edge in deps) {
      if (edge['predecessorId']?.toString() != id || edge['dependencyType']?.toString() != 'FS') continue;
      final successorId = edge['successorId']?.toString();
      for (final candidate in widget.projectItems) {
        if (candidate.id == successorId && candidate.status != 'cancelled') dependents.add(candidate);
      }
    }
    Map<String, dynamic>? linkedRef;
    for (final ref in refs) {
      if (ref['entityType'] == 'work_item' && ref['entityId']?.toString() == id && ref['moduleKey'] == 'procedure-engine') {
        linkedRef = ref;
        break;
      }
    }
    setState(() {
      _dependents = dependents;
      _linked = linkedRef != null;
      final code = linkedRef?['externalCode']?.toString();
      _linkedCode = (code != null && code.isNotEmpty) ? code : null;
    });
  }

  bool get _reasonOk => _reason.text.trim().length >= WorkspaceReverseApi.reasonMinLength;

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < WorkspaceReverseApi.reasonMinLength) {
      setState(() => _error = 'workspace.reverse.err_reason_min'.tr());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await _api.reverseWorkItem(widget.item.id, reason: reason, createAdjustment: _adjust);
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _submitting = false;
        _error = res.error ?? 'workspace.reverse.err_failed'.tr();
      });
      return;
    }
    Navigator.pop(context, _adjust && !_linked);
  }

  Widget _dependentsNotice() {
    final list = _dependents.take(5).map((d) => '${d.code} (${d.title})').join(', ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        'workspace.reverse.dependents'.tr(args: {
          'count': '${_dependents.length}',
          'list': list,
          'more': _dependents.length > 5 ? '…' : '',
        }),
        style: const TextStyle(fontSize: 13, color: Color(0xFF7C2D12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final linkedCode = _linkedCode;
    final hint = 'workspace.reverse.reason_hint'.tr() +
        (linkedCode != null ? 'workspace.reverse.reason_hint_linked'.tr(args: {'code': linkedCode}) : '');
    return AlertDialog(
      title: Text(
        'workspace.reverse.title'.tr(args: {'code': item.code, 'title': item.title}),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'workspace.reverse.reason_label'.tr(),
                children: const [TextSpan(text: ' *', style: TextStyle(color: Color(0xFFDC2626)))],
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reason,
              autofocus: true,
              minLines: 3,
              maxLines: 3,
              maxLength: WorkspaceReverseApi.reasonMaxLength,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'workspace.reverse.reason_placeholder'.tr(),
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
                counterText: '',
              ),
            ),
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            if (_dependents.isNotEmpty) _dependentsNotice(),
            InkWell(
              onTap: _submitting ? null : () => setState(() => _adjust = !_adjust),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _adjust,
                      onChanged: _submitting ? null : (v) => setState(() => _adjust = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('workspace.reverse.adjust_label'.tr(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(
                          linkedCode != null
                              ? 'workspace.reverse.adjust_hint_linked'.tr()
                              : 'workspace.reverse.adjust_hint'.tr(),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text('workspace.action.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: (_submitting || !_reasonOk) ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('workspace.reverse.confirm'.tr()),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../../features/workspace/data/datasources/workspace_checklist_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/app_toast.dart';
import '../../../../utils/user_resolver.dart';
import 'workspace_checklist_access.dart';
import 'workspace_checklist_manage_dialog.dart';

/// Card "Checklist tiến độ" (web `checklist-panel.tsx`): tích để hoàn thành, % theo đầu việc, "Hoàn thành bởi …";
/// thêm / sửa tên / xoá nằm trong hộp "Quản lý checklist". Việc dự án dùng `/work-items/:id/checklist`, Công việc
/// khác dùng `/standalone-tasks/:id/checklist` (luôn tính theo checklist).
///
/// Thao tác hiện ngay trên màn rồi gửi server lần lượt (hàng đợi), lỗi thì khôi phục kèm lời của server; khi không
/// còn yêu cầu nào chờ thì gọi [onChanged] để màn nạp lại tiến độ / trạng thái.
class WorkspaceChecklistPanel extends StatefulWidget {
  final StandaloneTaskItem item;
  final WorkspaceService service;
  final bool canEdit;
  final String? currentUserId;
  final VoidCallback onChanged;

  const WorkspaceChecklistPanel({
    super.key,
    required this.item,
    required this.service,
    required this.canEdit,
    required this.currentUserId,
    required this.onChanged,
  });

  @override
  State<WorkspaceChecklistPanel> createState() => _WorkspaceChecklistPanelState();
}

class _WorkspaceChecklistPanelState extends State<WorkspaceChecklistPanel> {
  final WorkspaceChecklistApi _api = WorkspaceChecklistApi();
  List<ChecklistEntry>? _items;
  bool _failed = false;
  /// Server đã tự chuyển việc thủ công sang `checklist` (lần thêm đầu tiên) nhưng `item` chưa kịp nạp lại.
  bool _switched = false;
  int _pending = 0;
  int _generation = 0;
  int _writeSeq = 0;
  int _tempSeq = 0;
  bool _dirty = false;
  Future<void> _tail = Future.value();

  StandaloneTaskItem get _item => widget.item;
  bool get _standalone => !_item.isProjectTask;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkspaceChecklistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_item.id != oldWidget.item.id) {
      // Sang việc khác: bỏ danh sách và hàng đợi của việc trước.
      _items = null;
      _failed = false;
      _switched = false;
      _pending = 0;
      _dirty = false;
      _generation++;
      _tail = Future.value();
      _load();
      return;
    }
    if (_item.progressMethod == 'checklist') _switched = false;
    if (_item.progressPercent != oldWidget.item.progressPercent ||
        _item.status != oldWidget.item.status ||
        _item.progressMethod != oldWidget.item.progressMethod) {
      _load(); // nạp lại ngầm, giữ danh sách cũ
    }
  }

  /// Bỏ kết quả nếu trong lúc chờ đã có thao tác ghi (kẻo đè thao tác lạc quan).
  Future<void> _load({bool force = false}) async {
    final seq = _writeSeq;
    final id = _item.id;
    final res = await _api.list(taskId: id, isProjectTask: _item.isProjectTask);
    if (!mounted || _item.id != id) return;
    if (_pending > 0 || (!force && seq != _writeSeq)) return;
    setState(() {
      if (res.ok) {
        _items = res.data ?? const [];
        _failed = false;
      } else if (_items == null) {
        _failed = true;
      }
    });
  }

  void _commit(List<ChecklistEntry> next) => setState(() => _items = next);

  Future<void> _notifyChanged() async {
    _dirty = false;
    widget.onChanged();
  }

  /// Gửi một thao tác ghi (đã áp lên màn) qua hàng đợi của công việc.
  Future<bool> _write(
    Future<WorkspaceApiResult<List<ChecklistEntry>>> Function() operation,
    String fallbackKey,
    VoidCallback rollback,
  ) async {
    final generation = _generation;
    _pending++;
    _writeSeq++;
    final run = _tail.then((_) => operation());
    _tail = run.then((_) {}, onError: (_) {});
    final res = await run;
    if (!mounted) return false;
    if (generation != _generation) {
      if (res.ok) widget.onChanged();
      return false;
    }
    if (!res.ok) {
      _pending--;
      rollback();
      AppToast.error(context, res.error ?? fallbackKey.tr());
      if (_pending == 0) {
        _load(force: true);
        if (_dirty) await _notifyChanged();
      }
      return false;
    }
    final accept = _pending <= 1;
    _pending--;
    if (accept && res.data != null) _commit(res.data!);
    _dirty = true;
    if (_pending <= 0) await _notifyChanged();
    return true;
  }

  String get _method => _standalone || _switched ? 'checklist' : (_item.progressMethod ?? 'manual');

  void _toggle(ChecklistEntry entry, bool done) {
    final items = _items;
    if (items == null || entry.id.startsWith('tmp:')) return;
    ChecklistEntry? before;
    for (final e in items) {
      if (e.id == entry.id) before = e;
    }
    if (before == null) return;
    final original = before;
    _commit(items.map((e) => e.id == entry.id ? e.withDone(done, by: widget.currentUserId, at: DateTime.now()) : e).toList());
    _write(
      () => _api.update(taskId: _item.id, isProjectTask: _item.isProjectTask, itemId: entry.id, done: done),
      'workspace.checklist.error_update',
      () => _commit((_items ?? const []).map((e) => e.id == original.id ? original : e).toList()),
    );
  }

  void _addTitles(List<String> titles) {
    final list = titles
        .map((t) => t.trim())
        .map((t) => t.length > checklistTitleMaxLength ? t.substring(0, checklistTitleMaxLength) : t)
        .where((t) => t.isNotEmpty)
        .toList();
    if (list.isEmpty) return;
    final current = _items ?? const <ChecklistEntry>[];
    final room = maxChecklistItems - current.length;
    if (room <= 0) {
      AppToast.error(context, 'workspace.checklist.max_items'.tr(args: {'max': maxChecklistItems}));
      return;
    }
    if (list.length > room) {
      AppToast.error(context, 'workspace.checklist.max_items_trimmed'.tr(args: {'max': maxChecklistItems}));
    }
    final batch = list.take(room).toList();
    final temps = [for (final t in batch) ChecklistEntry(id: 'tmp:${++_tempSeq}', title: t, done: false)];
    final tempIds = temps.map((e) => e.id).toSet();
    final switches = _method == 'manual' && current.isEmpty;
    if (switches) _switched = true;
    _commit([...current, ...temps]);
    _write(
      () => _api.add(taskId: _item.id, isProjectTask: _item.isProjectTask, titles: batch),
      'workspace.checklist.error_add',
      () {
        _commit((_items ?? const []).where((e) => !tempIds.contains(e.id)).toList());
        if (switches && (_items ?? const []).isEmpty) setState(() => _switched = false);
      },
    );
  }

  /// Áp bản nháp: xoá, đổi tên rồi thêm; hiện ngay trên card và gửi server lần lượt.
  Future<void> _openManage() async {
    final changes = await WorkspaceChecklistManageDialog.show(context, _items ?? const []);
    if (!mounted || changes == null) return;
    for (final entry in changes.removed) {
      final index = (_items ?? const []).indexWhere((e) => e.id == entry.id);
      if (index < 0) continue;
      _commit((_items ?? const []).where((e) => e.id != entry.id).toList());
      _write(
        () => _api.remove(taskId: _item.id, isProjectTask: _item.isProjectTask, itemId: entry.id),
        'workspace.checklist.error_remove',
        () {
          final next = List<ChecklistEntry>.from(_items ?? const []);
          if (next.any((e) => e.id == entry.id)) return;
          next.insert(index.clamp(0, next.length), entry);
          _commit(next);
        },
      );
    }
    changes.renamed.forEach((id, title) {
      final before = (_items ?? const []).where((e) => e.id == id).firstOrNull;
      if (before == null) return;
      _commit((_items ?? const []).map((e) => e.id == id ? e.withTitle(title) : e).toList());
      _write(
        () => _api.update(taskId: _item.id, isProjectTask: _item.isProjectTask, itemId: id, title: title),
        'workspace.checklist.error_rename',
        () => _commit((_items ?? const []).map((e) => e.id == id ? e.withTitle(before.title) : e).toList()),
      );
    });
    if (changes.added.isNotEmpty) _addTitles(changes.added);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = items?.length ?? 0;
    final closed = _item.status == 'done' || _item.status == 'cancelled';
    final state = checklistPanelState(
      method: _method,
      closed: closed,
      canEdit: widget.canEdit,
      total: total,
      cannotEditReasonKey: _standalone ? standaloneChecklistReadonlyNoteKey : null,
    );
    if (!state.visible && !_failed) return const SizedBox.shrink();

    final doneCount = items?.where((e) => e.done).length ?? 0;
    final percent = checklistPercent(doneCount, total);
    final switchNotice = state.canAdd && _method == 'manual' && total == 0;
    const muted = TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'workspace.checklist.title'.tr(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              if (total > 0) ...[const SizedBox(width: 8), _countBadge('$doneCount/$total')],
              const Spacer(),
              if (state.canAdd && items != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: Text((total > 0 ? 'workspace.checklist.manage' : 'workspace.checklist.add_first').tr()),
                  onPressed: _openManage,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_failed)
            Text('workspace.checklist.load_failed'.tr(), style: muted)
          else if (items == null)
            Text('common.loading'.tr(), style: muted)
          else ...[
            if (total > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$percent%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: UserResolver.changeNotifier,
                builder: (context, _, _) => Column(
                  children: [for (final entry in items) _buildRow(entry, state.editable)],
                ),
              ),
            ] else
              _note(
                (switchNotice
                        ? 'workspace.checklist.empty_switch'
                        : state.canAdd
                            ? 'workspace.checklist.empty_can_add'
                            : 'workspace.checklist.empty')
                    .tr(),
              ),
            if (state.reasonKey.isNotEmpty) ...[const SizedBox(height: 10), _note(state.reasonKey.tr())],
          ],
        ],
      ),
    );
  }

  Widget _countBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      );

  Widget _note(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4))),
        ],
      );

  Widget _buildRow(ChecklistEntry entry, bool editable) {
    final pending = entry.id.startsWith('tmp:');
    var doneNote = '';
    if (entry.done && (entry.doneBy != null || entry.doneAt != null)) {
      final name = entry.doneBy != null ? UserResolver.resolveName(entry.doneBy) : '—';
      final date = entry.doneAt != null ? ' · ${DateFormat('dd/MM').format(entry.doneAt!)}' : '';
      doneNote = 'workspace.checklist.done_by'.tr(args: {'name': name}) + date;
    }
    final enabled = editable && !pending;
    return Opacity(
      opacity: pending ? 0.6 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => _toggle(entry, !entry.done) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: entry.done,
                visualDensity: VisualDensity.compact,
                activeColor: const Color(0xFF16A34A),
                onChanged: enabled ? (v) => _toggle(entry, v ?? false) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: entry.done ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                        decoration: entry.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (doneNote.isNotEmpty)
                      Text(doneNote, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

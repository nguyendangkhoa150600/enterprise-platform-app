import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_activity_api.dart';
import '../../../../features/workspace/domain/models/workspace_report_models.dart' show TagItem;
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/user_resolver.dart';
import 'workspace_activity_labels.dart';
import 'workspace_activity_model.dart';

/// Chấm của khối chỉ có dòng sửa trường (web `EDIT_DOT_COLOR`).
const Color _kEditDot = Color(0xFF94A3B8);

const Set<String> _kFieldKeys = {
  'title', 'description', 'priority', 'assigneeUserId', 'participantUserIds', 'followerUserIds', 'tagIds',
  'plannedStart', 'plannedEnd', 'dueDate', 'estimateHours', 'weight', 'progressMethod', 'quantityTarget',
  'quantityUnit', 'equalChildWeight', 'progressPercent', 'manualProgressPercent',
};
const Set<String> _kProgressMethods = {'manual', 'quantity', 'checklist', 'child_weight'};
const Set<String> _kPriorities = {'low', 'normal', 'high', 'urgent'};

/// Lịch sử hoạt động như web `tab-activity.tsx`: tab Hoạt động của dự án ([itemIds] null) hoặc một nhánh công việc
/// ([itemIds] = việc + con cháu; con cháu cũng được tự bổ sung từ [projectItems] như web `branchOf`).
class WorkspaceActivityList extends StatefulWidget {
  final String projectId;
  final WorkspaceService service;
  final Set<String>? itemIds;
  final List<StandaloneTaskItem> projectItems;
  final void Function(String itemId)? onOpenItem;
  /// true: nằm trong một cột cuộn có sẵn (shrinkWrap), false: tự cuộn (tab toàn màn).
  final bool embedded;
  /// Người tạo / thời điểm tạo dự án: dòng "Dự án được tạo" ở nhật ký cả dự án (web prop `created`).
  final String? projectCreatedBy;
  final String? projectCreatedAt;

  const WorkspaceActivityList({
    super.key,
    required this.projectId,
    required this.service,
    required this.projectItems,
    this.itemIds,
    this.onOpenItem,
    this.embedded = true,
    this.projectCreatedBy,
    this.projectCreatedAt,
  });

  @override
  State<WorkspaceActivityList> createState() => _WorkspaceActivityListState();
}

class _WorkspaceActivityListState extends State<WorkspaceActivityList> {
  final WorkspaceActivityApi _api = WorkspaceActivityApi();
  bool _loading = true;
  String? _error;
  List<ActivityEntry> _entries = const [];
  Map<String, String> _tagNames = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkspaceActivityList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) _load();
  }

  Future<void> _load() async {
    if (widget.projectId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = _entries.isEmpty;
      _error = null;
    });
    final activity = _api.listProjectActivity(widget.projectId);
    final tags = widget.service.getWorkspaceTags().catchError((_) => <TagItem>[]);
    final users = UserResolver.ensureLoaded().catchError((_) {});
    final result = await activity;
    final tagList = await tags;
    await users;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _tagNames = {for (final t in tagList) t.id: t.name};
      if (result.ok) {
        _entries = (result.data ?? const []).map(ActivityEntry.fromJson).toList();
      } else {
        _error = result.error ?? 'workspace.activity.load_failed'.tr();
      }
    });
  }

  /// Web `branchOf`: các việc đã chọn + toàn bộ con cháu.
  Set<String>? get _branch {
    final roots = widget.itemIds;
    if (roots == null) return null;
    final childrenOf = <String, List<String>>{};
    for (final it in widget.projectItems) {
      final parent = it.parentId;
      if (parent != null) childrenOf.putIfAbsent(parent, () => []).add(it.id);
    }
    final branch = <String>{};
    final queue = [...roots];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (branch.add(id)) queue.addAll(childrenOf[id] ?? const []);
    }
    return branch;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: UserResolver.changeNotifier,
      builder: (context, _, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_error != null) return _wrap([_errorBox(theme)]);

    final branch = _branch;
    final scope = branch == null
        ? _entries
        : _entries.where((e) => e.workItemId != null && branch.contains(e.workItemId)).toList();
    final createdAt = branch == null ? widget.projectCreatedAt : null;
    final createdKey = createdAt != null ? dayKeyOf(createdAt) : null;
    final days = groupActivity(scope);
    if (createdKey != null && createdKey.isNotEmpty && !days.any((d) => d.key == createdKey)) {
      final at = days.indexWhere((d) => d.key.compareTo(createdKey) < 0);
      days.insert(at < 0 ? days.length : at, ActivityDay(createdKey, []));
    }

    if (scope.isEmpty && createdKey == null) {
      return _wrap([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('workspace.activity.empty'.tr(),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
      ]);
    }

    final itemOf = {for (final it in widget.projectItems) it.id: it};
    final total = scope.length + (createdKey != null ? 1 : 0);
    return _wrap([
      if (branch == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text('workspace.activity.title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('workspace.activity.event_count'.tr(args: {'count': total}),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      for (final day in days) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(_dayLabel(day.key),
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
        ),
        for (final block in day.blocks) _block(block, itemOf[block.workItemId], theme),
        if (createdKey == day.key) _createdBlock(createdAt!, theme),
      ],
    ]);
  }

  Widget _wrap(List<Widget> children) {
    if (widget.embedded) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }

  Widget _errorBox(ThemeData theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          TextButton(onPressed: _load, child: Text('common.retry'.tr())),
        ],
      );

  String _dayLabel(String key) {
    final now = DateTime.now().toUtc().toIso8601String();
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String();
    if (key == dayKeyOf(now)) return 'workspace.activity.today'.tr();
    if (key == dayKeyOf(yesterday)) return 'workspace.activity.yesterday'.tr();
    final parts = key.split('-');
    if (parts.length != 3) return key;
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return 'workspace.activity.day_label'.tr(args: {
      'weekday': 'workspace.activity.weekday_${date.weekday}'.tr(),
      'date': '${parts[2]}/${parts[1]}/${parts[0]}',
    });
  }

  String _timeOf(String iso) {
    final t = vnTimeOf(iso);
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Người không có trong danh bạ tổ chức: không hiện UUID thô.
  String _person(String id) =>
      UserResolver.resolveName(id, fallback: 'workspace.activity.unknown_user'.tr());

  Widget _block(ActivityBlock block, StandaloneTaskItem? item, ThemeData theme) {
    final latest = block.entries.first;
    final dot = latest.isFieldEdit ? _kEditDot : workItemStatusToneOf(latest.toStatus).fg;
    final isSelf = widget.itemIds?.contains(item?.id) ?? false;
    final open = item != null && widget.onOpenItem != null && !isSelf ? () => widget.onOpenItem!(item.id) : null;
    return _blockShell(
      theme: theme,
      dot: dot,
      onTap: open,
      title: item == null
          ? Text('workspace.activity.deleted_item'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))
          : Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${item.code}  ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
                TextSpan(text: item.title),
              ]),
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: open != null ? theme.colorScheme.primary : null),
            ),
      rows: [for (final e in block.entries) _entryRow(e, theme)],
    );
  }

  Widget _createdBlock(String at, ThemeData theme) => _blockShell(
        theme: theme,
        dot: _kEditDot,
        title: Text('workspace.activity.project_created'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        rows: [
          _rowShell(
            theme,
            at,
            [
              _muted('workspace.activity.create_project'.tr(), theme),
              _actor(_person(widget.projectCreatedBy ?? ''), theme),
            ],
            const [],
          ),
        ],
      );

  Widget _blockShell({
    required ThemeData theme,
    required Color dot,
    required Widget title,
    required List<Widget> rows,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, ...rows],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _muted(String text, ThemeData theme) =>
      Text(text, style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant));

  Widget _actor(String name, ThemeData theme) =>
      Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600));

  Widget _rowShell(ThemeData theme, String at, List<Widget> head, List<Widget> notes) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: head),
                ...notes,
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_timeOf(at), style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _entryRow(ActivityEntry entry, ThemeData theme) {
    final actor = _person(entry.createdBy);
    if (entry.isFieldEdit) {
      return _rowShell(
        theme,
        entry.createdAt,
        [_muted('workspace.activity.edit_info'.tr(), theme), _actor(actor, theme)],
        [for (final c in entry.changes) _changeLine(c, theme)],
      );
    }
    final note = entry.note?.replaceFirst(RegExp(r'\s*·\s*$'), '').trim();
    final reversed = entry.toStatus == 'cancelled' && (entry.note?.startsWith('Huỷ hiệu lực:') ?? false);
    final deleted = entry.toStatus == 'cancelled' && (entry.note?.startsWith('Đã xoá công việc') ?? false);
    final toLabel = deleted
        ? 'workspace.activity.deleted_label'.tr()
        : reversed
            ? 'workspace.activity.reversed'.tr()
            : workItemStatusText(entry.toStatus);
    final tone = deleted
        ? const WorkItemStatusTone(Color(0xFFFEF2F2), Color(0xFFB91C1C))
        : reversed
            ? kReversedTone
            : workItemStatusToneOf(entry.toStatus);
    final split = note?.indexOf(' · ') ?? -1;
    final step = note != null && split > 0 ? note.substring(0, split) : note;
    final people = note != null && split > 0 ? note.substring(split + 3) : null;
    return _rowShell(
      theme,
      entry.createdAt,
      [
        if (entry.fromStatus != null) ...[
          _muted(workItemStatusText(entry.fromStatus), theme),
          _muted('→', theme),
        ] else
          _muted('workspace.activity.initial'.tr(), theme),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(10)),
          child: Text(toLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tone.fg)),
        ),
        _actor(actor, theme),
      ],
      [
        if (step != null && step.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: step, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (people != null)
                  TextSpan(text: ' · $people', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ]),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  Widget _changeLine(ActivityFieldChange change, ThemeData theme) {
    final text = _describe(change);
    final label = _kFieldKeys.contains(change.field) ? 'workspace.activity.field_${change.field}'.tr() : change.field;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (text.from != null) ...[
            TextSpan(text: text.from, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const TextSpan(text: ' → '),
          ],
          TextSpan(text: text.to),
        ]),
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }

  /// Web `FieldChangeList.describe`.
  ({String? from, String to}) _describe(ActivityFieldChange change) {
    final from = change.from;
    final to = change.to;
    String dash(dynamic v) => v == null ? '—' : _plain(v);
    switch (change.field) {
      case 'description':
        return (from: null, to: _truthy(to) ? 'workspace.activity.desc_edited'.tr() : 'workspace.activity.desc_cleared'.tr());
      case 'priority':
        return (from: _truthy(from) ? _priority('$from') : '—', to: _truthy(to) ? _priority('$to') : '—');
      case 'assigneeUserId':
        final none = 'workspace.activity.unassigned'.tr();
        return (from: _truthy(from) ? _person('$from') : none, to: _truthy(to) ? _person('$to') : none);
      case 'participantUserIds':
      case 'followerUserIds':
      case 'tagIds':
        String name(String id) => change.field == 'tagIds'
            ? (_tagNames[id] ?? 'workspace.activity.deleted_tag'.tr())
            : _person(id);
        final before = from is List ? from.map((e) => '$e').toList() : <String>[];
        final after = to is List ? to.map((e) => '$e').toList() : <String>[];
        final added = after.where((id) => !before.contains(id)).map(name).toList();
        final removed = before.where((id) => !after.contains(id)).map(name).toList();
        return (
          from: null,
          to: [
            if (added.isNotEmpty) 'workspace.activity.list_added'.tr(args: {'names': added.join(', ')}),
            if (removed.isNotEmpty) 'workspace.activity.list_removed'.tr(args: {'names': removed.join(', ')}),
          ].join('; '),
        );
      case 'plannedStart':
      case 'plannedEnd':
      case 'dueDate':
        final unset = 'workspace.activity.date_unset'.tr();
        return (from: _date(from) ?? unset, to: _date(to) ?? unset);
      case 'progressMethod':
        return (from: _truthy(from) ? _method('$from') : '—', to: _truthy(to) ? _method('$to') : '—');
      case 'equalChildWeight':
        return (from: _truthy(from) ? 'common.yes'.tr() : 'common.no'.tr(), to: _truthy(to) ? 'common.yes'.tr() : 'common.no'.tr());
      case 'estimateHours':
        String hours(dynamic v) => v == null ? '—' : 'workspace.activity.hours'.tr(args: {'value': _plain(v)});
        return (from: hours(from), to: hours(to));
      case 'progressPercent':
        return (from: '${_plain(from ?? 0)}%', to: '${_plain(to ?? 0)}%');
      case 'manualProgressPercent':
        final auto = 'workspace.activity.auto_progress'.tr();
        return (from: from == null ? auto : '${_plain(from)}%', to: to == null ? auto : '${_plain(to)}%');
      default:
        return (from: dash(from), to: dash(to));
    }
  }

  static bool _truthy(dynamic v) => v != null && v != false && v != '' && v != 0;

  static String _plain(dynamic v) {
    if (v is num && v == v.roundToDouble()) return v.toInt().toString();
    return '$v';
  }

  static String _priority(String v) => _kPriorities.contains(v) ? 'workspace.priority.$v'.tr() : v;

  static String _method(String v) =>
      _kProgressMethods.contains(v) ? 'workspace.activity.method_$v'.tr() : v;

  /// Web `formatDate`: cắt "yyyy-mm-dd" → "dd/mm/yyyy"; rỗng → null.
  static String? _date(dynamic v) {
    if (v == null || '$v'.length < 10) return null;
    final p = '$v'.substring(0, 10).split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : null;
  }
}

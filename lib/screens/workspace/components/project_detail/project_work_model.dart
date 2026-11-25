import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';

/// Logic thuần của tab Công việc (web tab-work.tsx + project-tree.model.ts + workspace-labels.ts):
/// bộ lọc, sắp xếp, dựng cây WBS, nhãn và màu trạng thái/ưu tiên.

/// Thứ tự trạng thái và ưu tiên như mặc định của web (workItemStatusKeys / priorityKeys).
const List<String> kWorkItemStatuses = ['todo', 'in_progress', 'blocked', 'review', 'done', 'cancelled'];
const List<String> kWorkItemPriorities = ['low', 'normal', 'high', 'urgent'];
const List<String> kProjectStatuses = ['planning', 'active', 'on_hold', 'completed', 'cancelled'];

const List<String> kWorkSorts = ['wbs', 'code', 'title', 'end', 'start', 'priority', 'status', 'progress'];
const List<String> kDueFilters = ['all', 'overdue', 'week', 'month'];

/// Bộ lọc + sắp xếp của bảng công việc; phần lọc cũng là nội dung một mẫu lọc đã lưu.
@immutable
class WorkFilter {
  final String status;
  final String priority;
  final String person; // 'all' | 'me' | 'none' | userId
  final String tag;
  final String due; // 'all' | 'overdue' | 'week' | 'month'
  final String sort;
  final bool ascending;
  final bool showChildren;

  const WorkFilter({
    this.status = 'all',
    this.priority = 'all',
    this.person = 'all',
    this.tag = 'all',
    this.due = 'all',
    this.sort = 'wbs',
    this.ascending = true,
    this.showChildren = true,
  });

  static const WorkFilter none = WorkFilter();

  bool get filtering => status != 'all' || priority != 'all' || person != 'all' || tag != 'all' || due != 'all';
  int get facets => [status, priority, person, tag, due].where((v) => v != 'all').length;
  bool get sorted => sort != 'wbs' || !ascending;

  WorkFilter copyWith({
    String? status,
    String? priority,
    String? person,
    String? tag,
    String? due,
    String? sort,
    bool? ascending,
    bool? showChildren,
  }) =>
      WorkFilter(
        status: status ?? this.status,
        priority: priority ?? this.priority,
        person: person ?? this.person,
        tag: tag ?? this.tag,
        due: due ?? this.due,
        sort: sort ?? this.sort,
        ascending: ascending ?? this.ascending,
        showChildren: showChildren ?? this.showChildren,
      );

  /// "Bỏ lọc": về không lọc, thứ tự WBS tăng dần; giữ lựa chọn "Hiện việc con".
  WorkFilter cleared() => WorkFilter(showChildren: showChildren);

  /// Nội dung lưu vào mẫu lọc (web `filter: { ...filter }`).
  Map<String, dynamic> toSaved() => {'status': status, 'priority': priority, 'person': person, 'tag': tag, 'due': due};

  /// Đọc lại mẫu đã lưu; trường lạ hay thiếu thì về "Tất cả" (web `filterFrom`).
  WorkFilter applySaved(Map<String, dynamic> saved) {
    String text(String key) {
      final v = saved[key];
      return v is String && v.isNotEmpty ? v : 'all';
    }

    return copyWith(
      status: text('status'),
      priority: text('priority'),
      person: text('person'),
      tag: text('tag'),
      due: text('due'),
    );
  }
}

/// Một dòng của bảng WBS.
class WorkTreeRow {
  final StandaloneTaskItem item;
  final int depth;
  final bool hasChildren;
  final bool expanded;

  const WorkTreeRow(this.item, this.depth, this.hasChildren, this.expanded);
}

/// Người phụ trách đứng đầu, sau đó là người cùng thực hiện.
List<String> peopleOf(StandaloneTaskItem item) =>
    [item.assigneeUserId, ...item.participantUserIds].where((id) => id.isNotEmpty).toSet().toList();

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Việc đóng muộn KHÔNG tính là quá hạn (web `isOverdue`).
bool isWorkItemOverdue(StandaloneTaskItem item) {
  if (item.status == 'done' || item.status == 'cancelled') return false;
  final end = item.dueDate;
  if (end == null) return false;
  return _dayKey(end).compareTo(_dayKey(DateTime.now())) < 0;
}

/// Việc khớp bộ lọc (web `matched`).
List<StandaloneTaskItem> matchWorkItems(List<StandaloneTaskItem> items, WorkFilter f, String? currentUserId) {
  final now = DateTime.now();
  final today = _dayKey(now);
  final weekEnd = _dayKey(now.add(const Duration(days: 7)));
  final month = today.substring(0, 7);
  return items.where((item) {
    if (f.status != 'all' && item.status != f.status) return false;
    if (f.priority != 'all' && item.priority != f.priority) return false;
    final people = peopleOf(item);
    if (f.person == 'me' && !people.contains(currentUserId)) return false;
    if (f.person == 'none' && people.isNotEmpty) return false;
    if (!['all', 'me', 'none'].contains(f.person) && !people.contains(f.person)) return false;
    if (f.tag != 'all' && !item.tagIds.contains(f.tag)) return false;
    final end = item.dueDate == null ? null : _dayKey(item.dueDate!);
    if (f.due == 'overdue' && !isWorkItemOverdue(item)) return false;
    if (f.due == 'week' && !(end != null && end.compareTo(today) >= 0 && end.compareTo(weekEnd) <= 0)) return false;
    if (f.due == 'month' && !(end != null && end.startsWith(month))) return false;
    return true;
  }).toList();
}

int compareCodeNumeric(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// So sánh hai việc cùng cấp; việc thiếu ngày luôn xếp cuối; hoà thì về thứ tự WBS (web `workComparator`).
int Function(StandaloneTaskItem, StandaloneTaskItem) workComparator(String sort, bool ascending) {
  final sign = ascending ? 1 : -1;
  int wbs(StandaloneTaskItem a, StandaloneTaskItem b) {
    final s = a.meta.sortOrder.compareTo(b.meta.sortOrder);
    return s != 0 ? s : compareCodeNumeric(a.code, b.code);
  }

  int byDate(DateTime? l, DateTime? r) {
    if (l == null && r == null) return 0;
    if (l == null) return 1;
    if (r == null) return -1;
    return sign * _dayKey(l).compareTo(_dayKey(r));
  }

  int primary(StandaloneTaskItem a, StandaloneTaskItem b) {
    switch (sort) {
      case 'code':
        return sign * compareCodeNumeric(a.code, b.code);
      case 'title':
        return sign * a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case 'end':
        return byDate(a.dueDate, b.dueDate);
      case 'start':
        return byDate(a.plannedStart, b.plannedStart);
      case 'priority':
        return sign * (kWorkItemPriorities.indexOf(a.priority) - kWorkItemPriorities.indexOf(b.priority));
      case 'status':
        return sign * (kWorkItemStatuses.indexOf(a.status) - kWorkItemStatuses.indexOf(b.status));
      case 'progress':
        return sign * a.progressPercent.compareTo(b.progressPercent);
      default:
        return sign * wbs(a, b);
    }
  }

  return (a, b) {
    final p = primary(a, b);
    return p != 0 ? p : wbs(a, b);
  };
}

/// Cây WBS (web `buildWorkItemTree`): giữ tổ tiên của mọi việc khớp lọc; nhánh thu gọn không bung con.
List<WorkTreeRow> buildWorkTree(
  List<StandaloneTaskItem> items,
  Set<String> visibleIds, {
  Set<String> collapsed = const {},
  int Function(StandaloneTaskItem, StandaloneTaskItem)? compare,
}) {
  final byId = {for (final i in items) i.id: i};
  final childrenOf = <String, List<StandaloneTaskItem>>{};
  final roots = <StandaloneTaskItem>[];
  for (final item in items) {
    final parent = item.parentId;
    if (parent != null && byId.containsKey(parent)) {
      childrenOf.putIfAbsent(parent, () => []).add(item);
    } else {
      roots.add(item);
    }
  }

  final keep = <String>{};
  for (final item in items) {
    if (!visibleIds.contains(item.id)) continue;
    StandaloneTaskItem? cursor = item;
    while (cursor != null && keep.add(cursor.id)) {
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
  }

  final cmp = compare ?? workComparator('wbs', true);
  final rows = <WorkTreeRow>[];
  final emitted = <String>{};
  void emit(StandaloneTaskItem item, int depth) {
    if (!keep.contains(item.id) || !emitted.add(item.id)) return;
    final children = (childrenOf[item.id] ?? const []).where((c) => keep.contains(c.id)).toList();
    final isCollapsed = collapsed.contains(item.id);
    rows.add(WorkTreeRow(item, depth, children.isNotEmpty, children.isNotEmpty && !isCollapsed));
    if (isCollapsed) return;
    children.sort(cmp);
    for (final child in children) {
      emit(child, depth + 1);
    }
  }

  roots.sort(cmp);
  for (final root in roots) {
    emit(root, 0);
  }
  return rows;
}

/// Hàng của bảng theo bộ lọc hiện tại (tắt "Hiện việc con" thì chỉ còn các việc cấp gốc).
List<WorkTreeRow> workTableRows(
  List<StandaloneTaskItem> items,
  List<StandaloneTaskItem> matched,
  WorkFilter filter,
  Set<String> collapsed,
) {
  final hidden = filter.showChildren ? collapsed : items.map((i) => i.id).toSet();
  return buildWorkTree(items, matched.map((i) => i.id).toSet(),
      collapsed: hidden, compare: workComparator(filter.sort, filter.ascending));
}

/* ---------------------------------------------------------------- Nhãn & màu */

@immutable
class Tone {
  final Color bg;
  final Color fg;
  const Tone(this.bg, this.fg);
}

const Map<String, Tone> _workStatusTone = {
  'todo': Tone(Color(0x2E9CA3AF), Color(0xFF4B5563)),
  'in_progress': Tone(Color(0x263B82F6), Color(0xFF1D4ED8)),
  'blocked': Tone(Color(0x26EF4444), Color(0xFFB91C1C)),
  'review': Tone(Color(0x2EF59E0B), Color(0xFF92400E)),
  'done': Tone(Color(0x2610B981), Color(0xFF047857)),
  'cancelled': Tone(Color(0xFFF3F4F6), Color(0xFF6B7280)),
};

const Map<String, Tone> _priorityTone = {
  'urgent': Tone(Color(0xFFFEE2E2), Color(0xFF991B1B)),
  'high': Tone(Color(0xFFFFEDD5), Color(0xFF9A3412)),
  'normal': Tone(Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
  'low': Tone(Color(0xFFF1F5F9), Color(0xFF475569)),
};

const Tone _greyTone = Tone(Color(0xFFF1F5F9), Color(0xFF475569));

/// Màu trạng thái dự án dùng chung bảng với trạng thái công việc (web PROJECT_STATUS_TONE).
Tone projectStatusTone(String status) {
  switch (status) {
    case 'planning':
      return _workStatusTone['todo']!;
    case 'active':
      return _workStatusTone['in_progress']!;
    case 'on_hold':
      return _workStatusTone['review']!;
    case 'completed':
      return _workStatusTone['done']!;
    case 'cancelled':
      return _workStatusTone['cancelled']!;
    default:
      return _greyTone;
  }
}

String projectStatusLabel(String status) {
  switch (status) {
    case 'planning':
      return 'workspace.project_detail.status_planning'.tr();
    case 'active':
      return 'workspace.project_detail.status_active'.tr();
    case 'on_hold':
      return 'workspace.project_detail.status_on_hold'.tr();
    case 'completed':
      return 'workspace.project_detail.status_completed'.tr();
    case 'cancelled':
      return 'workspace.project_detail.status_cancelled'.tr();
    default:
      return status;
  }
}

Tone workItemStatusTone(StandaloneTaskItem item) =>
    item.isReversed ? const Tone(Color(0xFFFFF7ED), Color(0xFF9A3412)) : (_workStatusTone[item.status] ?? _greyTone);

String workStatusLabel(String status) =>
    kWorkItemStatuses.contains(status) ? 'workspace.work_tab.status_$status'.tr() : status;

/// Việc huỷ hiệu lực vẫn là `cancelled` nhưng hiện riêng (web `workItemStatusLabel`).
String workItemStatusLabel(StandaloneTaskItem item) =>
    item.isReversed ? 'workspace.project_detail.item_status_reversed'.tr() : workStatusLabel(item.status);

Tone priorityTone(String priority) => _priorityTone[priority] ?? _greyTone;

String priorityLabel(String priority) =>
    kWorkItemPriorities.contains(priority) ? 'workspace.priority.$priority'.tr() : priority;

String dueFilterLabel(String due) => 'workspace.work_tab.due_$due'.tr();
String sortLabel(String sort) => 'workspace.work_tab.sort_$sort'.tr();

/// `dd/MM` hoặc "—" (web `formatShortDate`).
String formatShortDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// `dd/MM/yyyy` hoặc "" (web `formatDate`).
String formatFullDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// "Nguyễn Văn An" → "NA": chữ đầu của họ và của tên gọi (web `initials`).
String nameInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = words.first[0];
  final last = words.length > 1 ? words.last[0] : '';
  return '$first$last'.toUpperCase();
}

/// Huy hiệu bo tròn dùng chung cho trạng thái / ưu tiên.
class ToneBadge extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool caps;

  const ToneBadge({super.key, required this.label, required this.tone, this.caps = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        caps ? label.toUpperCase() : label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tone.fg),
      ),
    );
  }
}

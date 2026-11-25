import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/domain/models/workspace_report_models.dart' show TagItem;
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'project_work_model.dart';

/// Bảng WBS dạng cây của tab Công việc (web tab-work.tsx, kiểu xem "Bảng"): mỗi dòng thụt theo cấp,
/// nhóm có nút mở/thu nhánh; cột Người thực hiện, Ưu tiên (ẩn ở dòng cha), Trạng thái, Bắt đầu,
/// Thời hạn (đỏ khi quá hạn), Trạng thái cuối và Tiến độ xếp thành hai hàng phụ cho vừa màn hình điện thoại.
class ProjectWorkTree extends StatelessWidget {
  final List<WorkTreeRow> rows;
  final Map<String, TagItem> tags;
  final ValueChanged<StandaloneTaskItem> onOpen;
  final ValueChanged<WorkTreeRow> onToggle;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;

  const ProjectWorkTree({
    super.key,
    required this.rows,
    required this.tags,
    required this.onOpen,
    required this.onToggle,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(10, 4, 10, 16),
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: rows.length,
      itemBuilder: (ctx, i) => _WorkRow(
        row: rows[i],
        rootStart: rows[i].depth == 0 && i > 0,
        tags: tags,
        onOpen: onOpen,
        onToggle: onToggle,
      ),
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(color: const Color(0xFFEAB308), onRefresh: onRefresh!, child: list);
  }
}

class _WorkRow extends StatelessWidget {
  final WorkTreeRow row;
  final bool rootStart;
  final Map<String, TagItem> tags;
  final ValueChanged<StandaloneTaskItem> onOpen;
  final ValueChanged<WorkTreeRow> onToggle;

  static const double _indent = 16;

  const _WorkRow({
    required this.row,
    required this.rootStart,
    required this.tags,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final overdue = isWorkItemOverdue(item);
    final tone = workItemStatusTone(item);
    return InkWell(
      onTap: () => onOpen(item),
      child: Container(
        padding: EdgeInsets.fromLTRB(row.depth * _indent, 8, 4, 8),
        decoration: BoxDecoration(
          color: row.hasChildren ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border(
            top: rootStart ? const BorderSide(color: Color(0xFFCBD5E1), width: 1.5) : BorderSide.none,
            bottom: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _lead(),
                Expanded(child: _title(item)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 5),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _People(userIds: peopleOf(item), item: item),
                  if (!row.hasChildren)
                    ToneBadge(label: priorityLabel(item.priority), tone: priorityTone(item.priority)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ToneBadge(label: workItemStatusLabel(item), tone: tone),
                      if (item.status == 'blocked' && !item.isReversed) _BlockedMark(reason: item.blockedReason),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 5),
              child: Row(
                children: [
                  // Việc lồng sâu bị thụt lề → để các ô ngày tự xuống dòng thay vì tràn.
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        _dateCell('workspace.work_tab.col_start'.tr(), formatShortDate(item.plannedStart), false),
                        _dateCell('workspace.work_tab.col_due'.tr(), formatShortDate(item.dueDate), overdue),
                        if (item.meta.statusChangedAt != null)
                          Tooltip(
                            message: 'workspace.work_tab.last_status_at'
                                .tr(args: {'time': _dateTime(item.meta.statusChangedAt!.toLocal())}),
                            child: _dateCell('workspace.work_tab.col_last'.tr(),
                                formatShortDate(item.meta.statusChangedAt!.toLocal()), false),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _progress(item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lead() {
    final item = row.item;
    if (row.hasChildren) {
      return InkWell(
        onTap: () => onToggle(row),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(row.expanded ? Icons.expand_more : Icons.chevron_right, size: 20, color: const Color(0xFF475569)),
        ),
      );
    }
    final IconData? icon = item.meta.isMilestone
        ? Icons.diamond_outlined
        : row.depth > 0
            ? Icons.subdirectory_arrow_right
            : null;
    return SizedBox(
      width: 24,
      height: 22,
      child: icon == null ? null : Icon(icon, size: 15, color: item.meta.isMilestone ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8)),
    );
  }

  Widget _title(StandaloneTaskItem item) {
    final itemTags = item.tagIds.map((id) => tags[id]).whereType<TagItem>().toList();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '${item.code}  ',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          TextSpan(
            text: item.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: row.hasChildren ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          for (final t in itemTags)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text(t.name,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _tagColor(t.color))),
              ),
            ),
        ]),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dateCell(String label, String value, bool danger) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label ', style: const TextStyle(color: Color(0xFF94A3B8))),
        TextSpan(
          text: value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: danger ? const Color(0xFFB91C1C) : const Color(0xFF334155),
          ),
        ),
      ]),
      style: const TextStyle(fontSize: 11),
    );
  }

  Widget _progress(StandaloneTaskItem item) {
    if (item.isReversed) {
      // Việc huỷ hiệu lực không tính tiến độ; 100% cũ sẽ gây hiểu nhầm.
      return Tooltip(
        message: 'workspace.work_tab.reversed_no_progress'.tr(),
        child: const Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }
    final value = item.progressPercent.clamp(0, 100).toDouble();
    final expected = item.meta.expectedProgressPercent;
    final done = value >= 100;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LayoutBuilder(
              builder: (ctx, c) => Stack(children: [
                Container(color: const Color(0xFFE2E8F0)),
                if (expected != null)
                  Container(width: c.maxWidth * (expected.clamp(0, 100) / 100), color: const Color(0xFFBFDBFE)),
                Container(
                  width: c.maxWidth * value / 100,
                  color: done ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${value.round()}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: expected != null && value < expected ? const Color(0xFFB91C1C) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  static String _dateTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${formatFullDate(d)}';

  static Color _tagColor(String? hex) {
    final v = hex?.replaceFirst('#', '');
    if (v == null || v.length != 6) return const Color(0xFF475569);
    final parsed = int.tryParse(v, radix: 16);
    return parsed == null ? const Color(0xFF475569) : Color(0xFF000000 | parsed);
  }
}

/// Người phụ trách đứng đầu kèm tên; người cùng thực hiện chồng avatar phía sau (tối đa 3, còn lại "+N").
class _People extends StatelessWidget {
  final List<String> userIds;
  final StandaloneTaskItem item;

  const _People({required this.userIds, required this.item});

  String _name(String id) => id == item.assigneeUserId && (item.assigneeName ?? '').isNotEmpty
      ? item.assigneeName!
      : UserResolver.resolveName(id);

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) return const SizedBox.shrink();
    final first = userIds.first;
    final others = userIds.skip(1).toList();
    final shown = others.take(2).toList();
    final more = others.length - shown.length;
    final avatars = [first, ...shown];
    return Tooltip(
      message: userIds.map(_name).join(', '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            width: 20 + (avatars.length - 1 + (more > 0 ? 1 : 0)) * 13.0,
            child: Stack(children: [
              for (var i = 0; i < avatars.length; i++)
                Positioned(left: i * 13.0, child: _avatar(nameInitials(_name(avatars[i])), const Color(0xFFEAB308))),
              if (more > 0) Positioned(left: avatars.length * 13.0, child: _avatar('+$more', const Color(0xFF94A3B8))),
            ]),
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(_name(first),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String text, Color bg) => CircleAvatar(
        radius: 10,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 9,
          backgroundColor: bg,
          child: Text(text, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
}

/// Dấu vướng mắc cạnh trạng thái; chạm để xem lý do (web BlockedReasonMark).
class _BlockedMark extends StatelessWidget {
  final String? reason;
  const _BlockedMark({this.reason});

  @override
  Widget build(BuildContext context) {
    final text = reason?.trim() ?? '';
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: text.isNotEmpty ? text : 'workspace.work_tab.blocked_no_reason'.tr(),
      child: Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Icon(Icons.warning_amber_rounded,
            size: 15, color: text.isNotEmpty ? const Color(0xFFB91C1C) : const Color(0xFF94A3B8)),
      ),
    );
  }
}

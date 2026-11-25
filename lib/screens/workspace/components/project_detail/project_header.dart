import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_project_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'project_work_model.dart';

/// Khối đầu của trang dự án (web project-header.tsx + project-progress-bar.tsx).
class ProjectHeader extends StatelessWidget {
  final ProjectItem project;
  final List<ProjectMemberItem> members;
  final int documentCount;
  final ProjectProgressInfo? progress;
  final VoidCallback onOpenMembers;

  /// Có giá trị khi người xem có quyền "Có thể cập nhật trạng thái dự án".
  final Future<void> Function(String status)? onChangeStatus;

  const ProjectHeader({
    super.key,
    required this.project,
    required this.members,
    required this.documentCount,
    required this.onOpenMembers,
    this.progress,
    this.onChangeStatus,
  });

  static const int _avatarsShown = 3;

  String _memberName(ProjectMemberItem m) =>
      (m.fullName ?? '').trim().isNotEmpty ? m.fullName!.trim() : UserResolver.resolveName(m.userId);

  @override
  Widget build(BuildContext context) {
    final p = project;
    final dates = (p.startDate != null || p.endDate != null)
        ? '${formatFullDate(p.startDate).isEmpty ? '—' : formatFullDate(p.startDate)} → '
            '${formatFullDate(p.endDate).isEmpty ? '—' : formatFullDate(p.endDate)}'
        : null;
    final facts = <(IconData, String, bool)>[
      (Icons.tag, p.code, true),
      if ((p.projectType ?? '').isNotEmpty) (Icons.sell_outlined, p.projectType!, false),
      (Icons.checklist, 'workspace.project_detail.meta_items'.tr(args: {'count': '${p.totalItems}'}), false),
      (Icons.people_outline, 'workspace.project_detail.meta_members'.tr(args: {'count': '${members.length}'}), false),
      (Icons.description_outlined, 'workspace.project_detail.meta_documents'.tr(args: {'count': '$documentCount'}), false),
      if (dates != null) (Icons.date_range_outlined, dates, false),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF7C3AED),
                child: Text(nameInitials(p.name),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.25)),
                    const SizedBox(height: 4),
                    onChangeStatus != null
                        ? _StatusPicker(status: p.status, onChange: onChangeStatus!)
                        : ToneBadge(label: projectStatusLabel(p.status), tone: projectStatusTone(p.status), caps: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: ProjectProgressBar(project: p, info: progress)),
              const SizedBox(width: 12),
              _avatars(),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onOpenMembers,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('workspace.work_tab.members_button'.tr(),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final f in facts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.$1, size: 13, color: const Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(f.$2,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: f.$3 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          fontWeight: f.$3 ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatars() {
    final shown = members.take(_avatarsShown).toList();
    final more = members.length - shown.length;
    final count = shown.length + (more > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 26,
      width: 26 + (count - 1) * 18.0,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 18.0,
              child: Tooltip(
                message: i < shown.length ? _memberName(shown[i]) : '',
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 11.5,
                    backgroundColor: i < shown.length ? const Color(0xFFEAB308) : const Color(0xFFE2E8F0),
                    child: Text(
                      i < shown.length ? nameInitials(_memberName(shown[i])) : '+$more',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: i < shown.length ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thanh tiến độ dự án: lớp đậm là thực tế, lớp sáng phía sau là dự kiến theo thời gian;
/// chậm hơn dự kiến thì số chuyển màu cảnh báo. Giữ lâu để xem đủ số và cách tính.
class ProjectProgressBar extends StatelessWidget {
  final ProjectItem project;
  final ProjectProgressInfo? info;

  const ProjectProgressBar({super.key, required this.project, this.info});

  @override
  Widget build(BuildContext context) {
    final actual = project.progressPercent.round();
    final expected = info?.expectedProgressPercent?.round();
    final late = expected != null && actual < expected;
    final method = info?.progressMethod;
    final lines = [
      'workspace.work_tab.progress_actual'.tr(args: {'value': '$actual'}),
      expected == null
          ? 'workspace.work_tab.progress_expected_none'.tr()
          : 'workspace.work_tab.progress_expected'.tr(args: {'value': '$expected'}),
      if (method != null && method.isNotEmpty)
        'workspace.work_tab.progress_method'.tr(args: {'method': _methodLabel(method)}),
    ];
    return Tooltip(
      message: lines.join('\n'),
      triggerMode: TooltipTriggerMode.tap,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 7,
                child: LayoutBuilder(
                  builder: (ctx, c) => Stack(
                    children: [
                      Container(color: const Color(0xFFE2E8F0)),
                      if (expected != null)
                        Container(
                          width: c.maxWidth * (expected.clamp(0, 100) / 100),
                          color: const Color(0xFFBFDBFE),
                        ),
                      Container(
                        width: c.maxWidth * (actual.clamp(0, 100) / 100),
                        color: actual >= 100 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('$actual%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: late ? const Color(0xFFB91C1C) : const Color(0xFF0F172A),
              )),
        ],
      ),
    );
  }

  static String _methodLabel(String method) {
    const known = ['avg_tasks', 'weighted_days', 'weighted_weight', 'weighted_hours'];
    return known.contains(method) ? 'workspace.work_tab.method_$method'.tr() : method;
  }
}

/// Huy hiệu trạng thái bấm được; "Đã huỷ" không có ở đây (huỷ đi qua "Huỷ dự án").
class _StatusPicker extends StatefulWidget {
  final String status;
  final Future<void> Function(String status) onChange;

  const _StatusPicker({required this.status, required this.onChange});

  @override
  State<_StatusPicker> createState() => _StatusPickerState();
}

class _StatusPickerState extends State<_StatusPicker> {
  bool _saving = false;

  Future<void> _pick(String next) async {
    if (next == widget.status) return;
    setState(() => _saving = true);
    try {
      await widget.onChange(next);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = projectStatusTone(widget.status);
    return PopupMenuButton<String>(
      enabled: !_saving,
      tooltip: 'workspace.work_tab.change_project_status'.tr(),
      onSelected: _pick,
      itemBuilder: (ctx) => [
        for (final s in kProjectStatuses.where((s) => s != 'cancelled'))
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                ToneBadge(label: projectStatusLabel(s), tone: projectStatusTone(s), caps: true),
                const Spacer(),
                if (s == widget.status) const Icon(Icons.check, size: 16, color: Color(0xFF0F172A)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(projectStatusLabel(widget.status).toUpperCase(),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tone.fg)),
            Icon(Icons.keyboard_arrow_down, size: 14, color: tone.fg),
          ],
        ),
      ),
    );
  }
}

/// Banner dự án lưu trữ (web projects-view.tsx archivedBanner) kèm nút "Mở lưu trữ".
class ProjectArchivedBanner extends StatelessWidget {
  final bool canUnarchive;
  final VoidCallback? onUnarchive;

  const ProjectArchivedBanner({super.key, required this.canUnarchive, this.onUnarchive});

  @override
  Widget build(BuildContext context) {
    final hint = canUnarchive
        ? 'workspace.project_detail.archived_hint_can_unarchive'.tr()
        : 'workspace.project_detail.archived_hint_no_permission'.tr();
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFFBEB),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'workspace.project_detail.archived_banner'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' $hint'),
              ]),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
            ),
          ),
          if (canUnarchive && onUnarchive != null)
            TextButton.icon(
              onPressed: onUnarchive,
              icon: const Icon(Icons.unarchive_outlined, size: 15),
              label: Text('workspace.work_tab.unarchive'.tr(), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

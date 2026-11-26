import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/tasks/tasks_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/tasks/crm_task_models.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../utils/crm_scope.dart';
import 'crm_task_actions.dart';

/// Trang "Việc cần xử lý" (web `tasks/tasks-page.tsx`): "Chờ tôi duyệt", "Việc của tôi", "Đang chờ duyệt". Bấm thẻ:
/// duyệt qua Quy trình thì mở hồ sơ bên Quy trình; còn lại mở báo giá kèm nút quay về. Đóng màn đã mở → tải lại.
class CrmTasksScreen extends StatefulWidget {
  const CrmTasksScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmTasksScreen> createState() => _CrmTasksScreenState();
}

enum _TaskGroup { awaiting, mine, waiting }

class _CrmTasksScreenState extends State<CrmTasksScreen> {
  CrmTaskList? _list;
  bool _loading = true;
  String? _error;
  int _request = 0;

  Future<void> _load() async {
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final next = await CrmTasksRepository.instance.myTasks();
      if (!mounted || id != _request) return;
      setState(() {
        _list = next;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || id != _request) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.tasks.load_failed');
        _loading = false;
      });
    }
  }

  Future<void> _open(CrmTask task) async {
    await openCrmTask(context, task);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(
        context,
        CrmView.tasks.label,
        actions: [
          IconButton(
            tooltip: 'crm.tasks.refresh'.tr(),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: CrmPageGuard(
        view: CrmView.tasks,
        onAllowed: _load,
        builder: (context, status) {
          final caps = status.capabilities;
          return RefreshIndicator(
            onRefresh: _load,
            child: ValueListenableBuilder<List<CrmPerson>>(
              valueListenable: CrmScope.instance.people,
              builder: (context, _, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_error != null) CrmBanner(message: _error!),
                  _TaskSection(
                    title: 'crm.tasks.group.awaiting'.tr(),
                    group: _TaskGroup.awaiting,
                    tasks: _list?.awaitingMe ?? const [],
                    loading: _loading,
                    emptyText: 'crm.tasks.empty.awaiting'.tr(),
                    onOpen: _open,
                  ),
                  _TaskSection(
                    title: 'crm.tasks.group.mine'.tr(),
                    group: _TaskGroup.mine,
                    tasks: _list?.mine ?? const [],
                    loading: _loading,
                    emptyText: 'crm.tasks.empty.mine'.tr(),
                    onOpen: _open,
                  ),
                  _TaskSection(
                    title: 'crm.tasks.group.waiting'.tr(),
                    group: _TaskGroup.waiting,
                    tasks: _list?.waiting ?? const [],
                    loading: _loading,
                    emptyText: (caps.isTenantAdmin || caps.canManage)
                        ? 'crm.tasks.empty.waiting_admin'.tr()
                        : 'crm.tasks.empty.waiting'.tr(),
                    onOpen: _open,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Một nhóm việc (web `TaskTable`): thẻ thay dòng bảng, phân trang 15 việc ngay trên trang.
class _TaskSection extends StatefulWidget {
  final String title;
  final _TaskGroup group;
  final List<CrmTask> tasks;
  final bool loading;
  final String emptyText;
  final Future<void> Function(CrmTask task) onOpen;

  const _TaskSection({
    required this.title,
    required this.group,
    required this.tasks,
    required this.loading,
    required this.emptyText,
    required this.onOpen,
  });

  @override
  State<_TaskSection> createState() => _TaskSectionState();
}

class _TaskSectionState extends State<_TaskSection> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final showMargin = crmTasksHaveMargin(tasks);
    // Danh sách tải lại ít đi: không để trang hiện tại vượt quá số trang.
    final current = math.min(_page, crmPageCount(tasks.length, kCrmListPageSize));
    final shown = tasks.skip((current - 1) * kCrmListPageSize).take(kCrmListPageSize).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmSectionTitle(widget.loading ? widget.title : '${widget.title} (${tasks.length})'),
          if (widget.loading && tasks.isEmpty)
            const CrmStateView(loading: true)
          else if (tasks.isEmpty)
            CrmCard(
              child: Text(widget.emptyText, style: const TextStyle(fontSize: 13, color: CrmColors.muted)),
            )
          else
            for (final task in shown)
              _TaskCard(task: task, group: widget.group, showMargin: showMargin, onTap: () => widget.onOpen(task)),
          if (tasks.length > kCrmListPageSize)
            CrmPagerBar(
              page: current,
              total: tasks.length,
              pageSize: kCrmListPageSize,
              loading: widget.loading,
              noun: 'crm.tasks.noun'.tr(),
              onChanged: (page) => setState(() => _page = page),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CrmTask task;
  final _TaskGroup group;
  final bool showMargin;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.group, required this.showMargin, required this.onTap});

  String _person(String? userId, String? name) =>
      (name != null && name.isNotEmpty) ? name : CrmScope.instance.personName(userId);

  @override
  Widget build(BuildContext context) {
    final mine = group == _TaskGroup.mine;
    final reasons = task.reasons;
    const lw = 116.0;
    return CrmCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CrmCodeBadge(task.quoteCode),
              const SizedBox(width: 6),
              Text('v${task.versionNo}', style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
              const Spacer(),
              Flexible(
                child: CrmStatusPill(label: crmTaskKindLabel(task.kind), tone: crmTaskKindTone(task.kind), dense: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.quoteLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          if (task.customerName != null && task.customerName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(task.customerName!, style: const TextStyle(fontSize: 12.5, color: CrmColors.body)),
          ],
          const SizedBox(height: 6),
          CrmInfoRow(label: 'crm.tasks.field.total'.tr(), value: formatCrmMoney(task.totalAmount), labelWidth: lw),
          if (showMargin)
            CrmInfoRow(
              label: 'crm.tasks.field.margin'.tr(),
              value: formatCrmPercent(task.marginPercent),
              labelWidth: lw,
            ),
          if (group == _TaskGroup.waiting)
            CrmInfoRow(label: 'crm.tasks.field.waiting_on'.tr(), value: task.waitingOn ?? '', labelWidth: lw),
          if (group == _TaskGroup.awaiting)
            CrmInfoRow(label: 'crm.tasks.field.mode'.tr(), value: crmApprovalModeText(task.approval), labelWidth: lw),
          mine
              ? CrmInfoRow(
                  label: 'crm.tasks.field.owner'.tr(),
                  value: _person(task.ownerUserId, task.ownerName),
                  labelWidth: lw,
                )
              : CrmInfoRow(
                  label: 'crm.tasks.field.actor'.tr(),
                  value: _person(task.actorUserId, task.actorName),
                  labelWidth: lw,
                ),
          CrmInfoRow(
            label: (mine ? 'crm.tasks.field.result_at' : 'crm.tasks.field.submitted_at').tr(),
            value: formatCrmDateTime(task.at),
            labelWidth: lw,
          ),
          if (reasons.isNotEmpty)
            CrmInfoRow(
              label: (mine ? 'crm.tasks.field.reason' : 'crm.tasks.field.approval_reason').tr(),
              value: reasons.join('\n'),
              labelWidth: lw,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              crmTaskActionLabel(task),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CrmColors.link),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/activities/activities_repository.dart';
import '../../domain/activities/crm_activity_models.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
import '../common/crm_format.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_activity_form_sheets.dart';

/// Danh sách hoạt động gắn khách hàng hoặc dự án bán hàng (web `ActivityPanel`): thêm, sửa, ghi kết quả, hoàn tất.
/// Dùng ở tab Hoạt động của khách, chi tiết dự án bán hàng và trang "Hoạt động".
///
/// Widget không tự cuộn (Column): đặt trong `ListView` / `SingleChildScrollView` của màn chứa. Gọi
/// `GlobalKey<CrmActivityPanelState>().currentState?.reload()` để tải lại (kéo để làm mới).
class CrmActivityPanel extends StatefulWidget {
  final CrmActivityScope scope;

  /// Mở sẵn hoạt động này (từ thông báo nhắc hạn).
  final String? focusId;

  /// Hiện khách hàng, dự án bán hàng trên thẻ (trang Hoạt động).
  final bool showTarget;

  /// Lọc trạng thái lúc mở, ví dụ `OPEN` ở trang Hoạt động.
  final String defaultStatus;

  const CrmActivityPanel({
    super.key,
    required this.scope,
    this.focusId,
    this.showTarget = false,
    this.defaultStatus = '',
  });

  @override
  State<CrmActivityPanel> createState() => CrmActivityPanelState();
}

class CrmActivityPanelState extends State<CrmActivityPanel> {
  final CrmActivitiesRepository _repo = CrmActivitiesRepository.instance;
  late String _status = widget.defaultStatus;
  late final CrmPagedListController<CrmActivity> _list = CrmPagedListController<CrmActivity>(
    key: _key,
    load: (page) => _repo.list(
      CrmActivityListQuery(
        scope: widget.scope,
        status: _status.isEmpty ? null : _status,
        page: page,
        limit: kCrmListPageSize,
      ),
    ),
  );
  String? _handledFocus;

  String get _key => '${widget.scope.key}|$_status';

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
    _list.reload();
    _openFocus();
  }

  @override
  void didUpdateWidget(covariant CrmActivityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Web dựng lại panel theo phạm vi (`key={assigneeUserId}`): bộ lọc trạng thái về mặc định.
    if (oldWidget.scope.key != widget.scope.key) {
      _status = widget.defaultStatus;
      _list.setKey(_key);
    }
    if (oldWidget.focusId != widget.focusId) _openFocus();
  }

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Tải lại trang đang xem.
  Future<void> reload() => _list.reload();

  /// Mở hoạt động được trỏ tới từ thông báo (một lần cho mỗi id).
  Future<void> _openFocus() async {
    final id = widget.focusId;
    if (id == null || id.isEmpty || _handledFocus == id) return;
    _handledFocus = id;
    try {
      final activity = await _repo.get(id);
      if (!mounted) return;
      await _edit(activity);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      showCrmSnack(context, crmErrorMessage(e, 'crm.activities.open_failed'), error: true);
    }
  }

  Future<void> _edit(CrmActivity? activity) async {
    final saved = await showCrmActivityForm(context, activity: activity, scope: widget.scope);
    if (!mounted) return;
    if (saved) _list.reload();
  }

  Future<void> _complete(CrmActivity activity) async {
    final saved = await showCrmCompleteActivity(context, activity);
    if (!mounted) return;
    if (saved) _list.reload();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = CrmScope.instance.capabilities.canWrite;
    final statusOptions = crmLabelOptions(crmActivityStatusLabels());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canWrite && widget.scope.hasTarget)
                SizedBox(
                  height: 36,
                  child: CrmButton(
                    label: 'crm.activities.add'.tr(),
                    icon: Icons.add_rounded,
                    onPressed: () => _edit(null),
                  ),
                ),
              CrmFilterChip(
                placeholder: 'crm.activities.all_statuses'.tr(),
                value: _status,
                options: statusOptions,
                searchable: false,
                onChanged: (value) {
                  setState(() => _status = value ?? '');
                  _list.setKey(_key);
                },
              ),
            ],
          ),
        ),
        if (_list.error != null) CrmBanner(message: _list.error!),
        if (_list.loading && _list.items.isEmpty)
          const CrmStateView(loading: true)
        else if (_list.items.isEmpty)
          CrmStateView(emptyIcon: Icons.event_note_outlined, emptyText: 'crm.activities.empty'.tr())
        else
          ValueListenableBuilder<List<CrmPerson>>(
            valueListenable: CrmScope.instance.people,
            builder: (context, _, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final activity in _list.items)
                  _ActivityCard(
                    activity: activity,
                    showTarget: widget.showTarget,
                    canWrite: canWrite,
                    onEdit: () => _edit(activity),
                    onComplete: () => _complete(activity),
                  ),
              ],
            ),
          ),
        CrmPagerBar.of(_list, noun: 'crm.activities.noun'.tr()),
      ],
    );
  }
}

const Map<String, CrmTone> _statusTone = {'OPEN': CrmTone.info, 'DONE': CrmTone.success, 'CANCELLED': CrmTone.neutral};

class _ActivityCard extends StatelessWidget {
  final CrmActivity activity;
  final bool showTarget;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onComplete;

  const _ActivityCard({
    required this.activity,
    required this.showTarget,
    required this.canWrite,
    required this.onEdit,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = activity.isOverdue();
    final target = activity.targetText;
    final result = activity.result;
    return CrmCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CrmCodeBadge(crmActivityTypeLabel(activity.type)),
              const Spacer(),
              overdue
                  ? CrmStatusPill(label: 'crm.activities.overdue'.tr(), tone: CrmTone.danger, dense: true)
                  : CrmStatusPill(
                      label: crmActivityStatusLabel(activity.status),
                      tone: _statusTone[activity.status] ?? CrmTone.neutral,
                      dense: true,
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activity.subject,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          const SizedBox(height: 4),
          if (showTarget && target.isNotEmpty)
            CrmInfoRow(label: 'crm.activities.field.target'.tr(), value: target, labelWidth: 110),
          CrmInfoRow(
            label: 'crm.activities.field.assignee'.tr(),
            value: CrmScope.instance.personName(activity.assigneeUserId),
            labelWidth: 110,
          ),
          if (activity.dueAt != null && activity.dueAt!.isNotEmpty)
            CrmInfoRow(
              label: 'crm.activities.field.due'.tr(),
              labelWidth: 110,
              child: Text(
                formatCrmDateTime(activity.dueAt),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                  color: overdue ? CrmColors.danger : CrmColors.text,
                ),
              ),
            ),
          if (result != null && result.isNotEmpty)
            CrmInfoRow(label: 'crm.activities.field.result'.tr(), value: result, labelWidth: 110),
          if (canWrite)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (activity.status == 'OPEN')
                  TextButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: Text('crm.activities.complete'.tr()),
                  ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text('crm.activities.edit'.tr()),
                ),
              ],
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

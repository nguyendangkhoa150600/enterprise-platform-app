import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_format.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import 'crm_opportunity_labels.dart';

/// "Việc của tôi" (web `MyStageTasks`): giai đoạn của dự án đang giao cho người dùng. Ẩn khi không có việc; mặc định
/// thu gọn. Tải lại khi [refresh] đổi.
class CrmMyStageTasks extends StatefulWidget {
  final int refresh;
  final ValueChanged<String> onOpen;
  const CrmMyStageTasks({super.key, required this.refresh, required this.onOpen});

  @override
  State<CrmMyStageTasks> createState() => _CrmMyStageTasksState();
}

class _CrmMyStageTasksState extends State<CrmMyStageTasks> {
  List<CrmMyStageTask> _tasks = const [];
  String? _error;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrmMyStageTasks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await OpportunitiesRepository.instance.myStageTasks();
      if (!mounted) return;
      setState(() {
        _tasks = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.opportunities.my_tasks.load_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return CrmBanner(message: _error!, margin: const EdgeInsets.fromLTRB(16, 8, 16, 0));
    if (_tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CrmCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        title: 'crm.opportunities.my_tasks.title'.tr(args: {'count': _tasks.length}),
        trailing: TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text((_expanded ? 'crm.opportunities.my_tasks.collapse' : 'crm.opportunities.my_tasks.expand').tr()),
        ),
        child: !_expanded
            ? const SizedBox.shrink()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 8),
                  children: [for (final t in _tasks) _task(t)],
                ),
              ),
      ),
    );
  }

  Widget _task(CrmMyStageTask t) {
    final overdue = CrmOpportunityRules.isDueOverdue(t.dueDate);
    var due = '';
    if (t.dueDate != null && t.dueDate!.isNotEmpty) {
      due = ' · ${'crm.opportunities.due'.tr(args: {'date': formatCrmDay(t.dueDate)})}';
      if (overdue) due += ' ${'crm.opportunities.overdue'.tr()}';
    }
    return InkWell(
      onTap: () => widget.onOpen(t.opportunityId),
      child: CrmOppTimelineItem(
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: t.opportunityName,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.link),
              ),
              TextSpan(text: '  ${t.customerName}', style: crmOppMuted),
            ],
          ),
        ),
        lines: [
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('crm.opportunities.my_tasks.stage'.tr(args: {'stage': t.stage.name}), style: crmOppMuted),
              CrmStatusPill(label: crmStagePlanLabel(t.status), tone: crmStagePlanTone(t.status), dense: true),
              if (due.isNotEmpty)
                Text(due, style: TextStyle(fontSize: 12, color: overdue ? CrmColors.danger : CrmColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
